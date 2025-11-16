import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:tree_sitter/tree_sitter.dart';

import 'grammar_manifest.dart';

/// Handles configuration of the shared Tree-sitter environment.
class TreeSitterEnvironment {
  TreeSitterEnvironment._();

  static bool _configured = false;
  static String? _languageDirectory;

  static Future<void> configure() async {
    if (_configured) return;
    _configured = true;
    _log('Configuring Tree-sitter');
    final coreLibEnv = Platform.environment['TREE_SITTER_CORE_LIB'];
    String? corePath;
    if (coreLibEnv != null && File(coreLibEnv).existsSync()) {
      corePath = coreLibEnv;
      _log('Using TREE_SITTER_CORE_LIB ($coreLibEnv)');
    } else {
      corePath = await _prepareCoreLibrary();
    }
    if (corePath != null) {
      try {
        TreeSitterConfig.setLibraryPath(corePath);
        _log('Core library ready at $corePath');
      } catch (error, stack) {
        _log('Failed to bind Tree-sitter core library: $error', stack);
      }
    } else {
      _log('Tree-sitter core library unavailable; syntax parsing disabled');
    }
    final langDir = Platform.environment['TREE_SITTER_LANG_DIR']?.trim();
    if (langDir != null && Directory(langDir).existsSync()) {
      _languageDirectory = langDir;
      _log('Using TREE_SITTER_LANG_DIR override: $langDir');
    } else {
      _log('Using default grammar directory: $languageDirectory');
    }
  }

  static String get languageDirectory =>
      _languageDirectory ?? p.join(Directory.current.path, 'tree_sitter_libs');
  static Future<String?> _prepareCoreLibrary() async {
    final descriptor = _PlatformDescriptor.current();
    if (descriptor == null) {
      _log(
        'Unsupported platform for Tree-sitter core: ${Platform.operatingSystem}',
      );
      return null;
    }
    final prefix = Platform.isWindows ? '' : 'lib';
    final fileName =
        '$prefix${_TreeSitterConstants.coreLibraryName}.${descriptor.libraryExtension}';
    final target = File(p.join(languageDirectory, fileName));
    if (target.existsSync()) {
      return target.path;
    }
    final error = await _buildCoreLibrary(target);
    if (error != null) {
      _log('Failed to prepare Tree-sitter core: $error');
      return null;
    }
    return target.path;
  }

  static Future<String?> _buildCoreLibrary(File target) async {
    final repo = _TreeSitterConstants.coreRepository;
    final archive = await _downloadRepositoryArchive(
      repo,
      'tree-sitter core',
      fallbackRefs: const ['master', 'main'],
    );
    if (archive == null) {
      return 'Unable to fetch source archive';
    }
    final tempDir = await Directory.systemTemp.createTemp('tree_sitter_core_');
    try {
      final rootDir = await _extractArchive(archive, tempDir);
      if (rootDir == null) {
        return 'Unable to extract core archive';
      }
      final source = File(p.join(rootDir, 'lib', 'src', 'lib.c'));
      if (!source.existsSync()) {
        return 'Missing lib/src/lib.c';
      }
      final includeDir = Directory(p.join(rootDir, 'lib', 'include'));
      final srcInclude = Directory(p.join(rootDir, 'lib', 'src'));
      final compiler = 'cc';
      final args = [
        '-std=gnu99',
        '-D_GNU_SOURCE',
        '-D_POSIX_C_SOURCE=200809L',
        '-fPIC',
        '-O3',
        '-I${includeDir.path}',
        '-I${srcInclude.path}',
        source.path,
        '-shared',
        '-o',
        target.path,
      ];
      try {
        final process = await Process.run(
          compiler,
          args,
          workingDirectory: rootDir,
        );
        if (process.exitCode != 0) {
          return 'Compiler error: ${process.stderr}';
        }
      } catch (error, stack) {
        _log('Failed to compile Tree-sitter core: $error', stack);
        return 'Compiler invocation failed';
      }
      _log('Built Tree-sitter core library at ${target.path}');
      return null;
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  }
}

class _PlatformDescriptor {
  _PlatformDescriptor({required this.libraryExtension});

  final String libraryExtension;

  static _PlatformDescriptor? current() {
    if (Platform.isLinux &&
        (Abi.current() == Abi.linuxX64 || Abi.current() == Abi.linuxArm64)) {
      return _PlatformDescriptor(libraryExtension: 'so');
    }
    if (Platform.isMacOS) {
      return _PlatformDescriptor(libraryExtension: 'dylib');
    }
    if (Platform.isWindows) {
      return _PlatformDescriptor(libraryExtension: 'dll');
    }
    _log(
      'Unsupported platform for native compilers: ${Platform.operatingSystem}',
    );
    return null;
  }
}

class TreeSitterGrammar {
  TreeSitterGrammar(this.record);

  final GrammarRecord record;

  static final Map<String, String> _entryPointOverrides = {
    'tsx': 'tree_sitter_tsx',
  };

  static final Map<String, String> _libraryNameOverrides = {
    'tsx': 'tree-sitter-tsx',
    'typescript': 'tree-sitter-typescript',
  };

  static final Map<String, String> _subdirOverrides = {
    'typescript': 'typescript',
    'tsx': 'tsx',
  };

  String get languageId => record.name;
  String get repository => record.repository;

  String get sharedLibraryName =>
      _libraryNameOverrides[languageId] ?? record.repo;

  String get entryPoint =>
      _entryPointOverrides[languageId] ??
      'tree_sitter_${languageId.replaceAll('-', '_')}';

  String? get subdirectory => _subdirOverrides[languageId];

  String get sharedLibraryPath {
    final descriptor = _PlatformDescriptor.current();
    final ext = descriptor?.libraryExtension ?? 'so';
    final prefix = Platform.isWindows ? '' : 'lib';
    final dir = Directory(TreeSitterEnvironment.languageDirectory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return p.join(dir.path, '$prefix$sharedLibraryName.$ext');
  }

  Future<String?> ensureAvailable() async {
    final file = File(sharedLibraryPath);
    if (file.existsSync()) {
      return null;
    }
    if (_copyFromNeovim(file)) {
      return null;
    }
    return _buildFromSource(file);
  }

  bool _copyFromNeovim(File target) {
    final descriptor = _PlatformDescriptor.current();
    final ext = descriptor?.libraryExtension ?? 'so';
    final base = languageId.split('_').first;
    final names = <String>{
      '$base.$ext',
      '$sharedLibraryName.$ext',
      'tree-sitter-$base.$ext',
    };
    final candidates = <String?>[
      Platform.environment['NVIM_TREESITTER_PARSER_DIR'],
      _expandHome('.local/share/nvim/site/parser'),
      _expandHome('.config/nvim/parser'),
      Platform.environment['LOCALAPPDATA'] != null
          ? p.join(
              Platform.environment['LOCALAPPDATA']!,
              'nvim-data',
              'site',
              'parser',
            )
          : null,
    ].whereType<String>();

    for (final dir in candidates) {
      for (final name in names) {
        final candidate = File(p.join(dir, name));
        if (candidate.existsSync()) {
          target.parent.createSync(recursive: true);
          candidate.copySync(target.path);
          _log(
            'Copied $languageId grammar from Neovim cache: ${candidate.path}',
          );
          return true;
        }
      }
    }
    return false;
  }

  Future<String?> _buildFromSource(File target) async {
    final descriptor = _PlatformDescriptor.current();
    if (descriptor == null) {
      return 'Unsupported platform ${Platform.operatingSystem}';
    }
    final tempDir = await Directory.systemTemp.createTemp(
      'tree_sitter_${languageId}_',
    );
    try {
      _log('Downloading $languageId grammar from $repository');
      final archiveBytes = await _downloadTarball();
      if (archiveBytes == null) {
        return 'Failed to download source archive';
      }
      final rootDir = await _extractArchive(
        archiveBytes,
        tempDir,
        subdirectory: subdirectory,
      );
      if (rootDir == null) {
        return 'Failed to extract $repository archive';
      }
      final success = await _compileGrammar(rootDir, target);
      if (!success) {
        return 'Compiler error (see console for details)';
      }
      _log('Built $languageId grammar -> ${target.path}');
      return null;
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  }

  Future<Uint8List?> _downloadTarball() async {
    return _downloadRepositoryArchive(
      repository,
      languageId,
      fallbackRefs: const ['main', 'master'],
    );
  }

  Future<bool> _compileGrammar(String rootDir, File target) async {
    final srcDir = Directory(p.join(rootDir, 'src'));
    if (!srcDir.existsSync()) {
      _log('Missing src directory for $languageId grammar');
      return false;
    }
    final parser = File(p.join(srcDir.path, 'parser.c'));
    if (!parser.existsSync()) {
      _log('Missing parser.c for $languageId');
      return false;
    }
    final scannerC = File(p.join(srcDir.path, 'scanner.c'));
    final scannerCc = File(p.join(srcDir.path, 'scanner.cc'));
    final usesCxx = scannerCc.existsSync();
    final compiler = usesCxx ? 'g++' : 'cc';
    final args = <String>['-shared', '-fPIC', '-O3', '-Isrc', parser.path];
    if (scannerC.existsSync()) {
      args.add(scannerC.path);
    }
    if (scannerCc.existsSync()) {
      args.add(scannerCc.path);
    }
    args
      ..add('-o')
      ..add(target.path);

    try {
      final process = await Process.run(
        compiler,
        args,
        workingDirectory: rootDir,
      );
      if (process.exitCode != 0) {
        _log(
          'Failed to compile $languageId using $compiler: ${process.stderr}',
        );
        return false;
      }
      return true;
    } catch (error, stack) {
      _log('Failed to spawn $compiler for $languageId: $error', stack);
      return false;
    }
  }

  String? _expandHome(String relative) {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return p.join(home, relative);
  }
}

class TreeSitterLanguageRegistry {
  static final Map<String, TreeSitterGrammar> _cache = {};

  static final Map<String, String> _extensionOverrides = {
    'yml': 'yaml',
    'yaml': 'yaml',
    'json': 'json',
    'toml': 'toml',
    'py': 'python',
    'pyw': 'python',
    'pyi': 'python',
    'rs': 'rust',
    'go': 'go',
    'sh': 'bash',
    'bash': 'bash',
    'zsh': 'bash',
    'js': 'javascript',
    'mjs': 'javascript',
    'cjs': 'javascript',
    'jsx': 'javascript',
    'ts': 'typescript',
    'tsx': 'tsx',
    'md': 'markdown',
    'markdown': 'markdown',
    'dockerfile': 'dockerfile',
  };

  static String? extensionForPath(String path) {
    final base = p.basename(path);
    final idx = base.lastIndexOf('.');
    if (idx <= 0 || idx == base.length - 1) return null;
    return base.substring(idx + 1).toLowerCase();
  }

  static TreeSitterGrammar? lookup(String? ext) {
    if (ext == null) return null;
    final normalized = _extensionOverrides[ext] ?? ext;
    final existing = _cache[normalized];
    if (existing != null) {
      return existing;
    }
    final record = GrammarManifest.lookup(normalized);
    if (record == null) {
      return null;
    }
    final grammar = TreeSitterGrammar(record);
    _cache[normalized] = grammar;
    return grammar;
  }
}

class _TreeSitterConstants {
  static const coreRepository = 'tree-sitter/tree-sitter';
  static const coreLibraryName = 'tree-sitter';
}

final Map<String, String?> _releaseCache = {};

Future<Uint8List?> _downloadRepositoryArchive(
  String repository,
  String logName, {
  Iterable<String> fallbackRefs = const ['main', 'master'],
}) async {
  final attempts = <String?>[];
  attempts.add(await _fetchLatestReleaseTagForRepo(repository));
  attempts.addAll(fallbackRefs);
  final tried = <String>{};
  for (final ref in attempts) {
    if (ref == null || ref.isEmpty || !tried.add(ref)) continue;
    final url = Uri.parse(
      'https://codeload.github.com/$repository/tar.gz/$ref',
    );
    try {
      final response = await http
          .get(url, headers: _githubHeaders())
          .timeout(const Duration(seconds: 30));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      _log(
        'Failed to download $logName ($repository@$ref): HTTP ${response.statusCode}',
      );
    } catch (error, stack) {
      _log('Download error for $logName@$ref: $error', stack);
    }
  }
  return null;
}

Future<String?> _fetchLatestReleaseTagForRepo(String repository) async {
  if (_releaseCache.containsKey(repository)) {
    return _releaseCache[repository];
  }
  final url = Uri.parse(
    'https://api.github.com/repos/$repository/releases/latest',
  );
  try {
    final response = await http
        .get(url, headers: _githubHeaders())
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = json['tag_name']?.toString();
      _releaseCache[repository] = tag;
      return tag;
    }
    if (response.statusCode == 404) {
      _releaseCache[repository] = null;
      return null;
    }
    _log(
      'GitHub release lookup failed for $repository (HTTP ${response.statusCode})',
    );
  } catch (error, stack) {
    _log('Failed to query releases for $repository: $error', stack);
  }
  _releaseCache[repository] = null;
  return null;
}

Future<String?> _extractArchive(
  Uint8List data,
  Directory tempDir, {
  String? subdirectory,
}) async {
  try {
    final tarBytes = GZipDecoder().decodeBytes(data);
    final archive = TarDecoder().decodeBytes(tarBytes);
    for (final entry in archive.files) {
      final filePath = p.join(tempDir.path, entry.name);
      if (entry.isFile) {
        final outFile = File(filePath)..createSync(recursive: true);
        outFile.writeAsBytesSync(entry.content as List<int>);
      } else {
        Directory(filePath).createSync(recursive: true);
      }
    }
    final root = archive.files
        .map((f) => f.name.split('/').first)
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    if (root.isEmpty) {
      return null;
    }
    final relative = subdirectory != null ? p.join(root, subdirectory) : root;
    return p.join(tempDir.path, relative);
  } catch (error, stack) {
    _log('Failed to extract archive: $error', stack);
    return null;
  }
}

class TreeSitterSession {
  TreeSitterSession._({
    required this.extension,
    required this.grammar,
    required Parser? parser,
    required this.statusMessage,
  }) : _parser = parser;

  final String? extension;
  final TreeSitterGrammar? grammar;
  final String statusMessage;
  final Parser? _parser;

  Parser? get parser => _parser;
  bool get isAvailable => _parser != null;
  String? get languageLabel => grammar?.languageId ?? extension;

  static Future<TreeSitterSession> forPath(String path) async {
    final ext = TreeSitterLanguageRegistry.extensionForPath(path);
    final grammar = TreeSitterLanguageRegistry.lookup(ext);
    if (grammar == null) {
      return TreeSitterSession._(
        extension: ext,
        grammar: null,
        parser: null,
        statusMessage: 'No grammar registered',
      );
    }
    final error = await grammar.ensureAvailable();
    if (error != null) {
      return TreeSitterSession._(
        extension: ext,
        grammar: grammar,
        parser: null,
        statusMessage: 'Unable to prepare grammar: $error',
      );
    }
    try {
      final parser = Parser(
        sharedLibrary: grammar.sharedLibraryPath,
        entryPoint: grammar.entryPoint,
      );
      return TreeSitterSession._(
        extension: ext,
        grammar: grammar,
        parser: parser,
        statusMessage: 'Syntax parser active',
      );
    } catch (error, stack) {
      _log(
        'Failed to instantiate parser for ${grammar.languageId}: $error',
        stack,
      );
      return TreeSitterSession._(
        extension: ext,
        grammar: grammar,
        parser: null,
        statusMessage: 'Failed to initialize parser',
      );
    }
  }
}

void _log(String message, [Object? error, StackTrace? stackTrace]) {
  developer.log(
    message,
    name: 'TreeSitter',
    error: error,
    stackTrace: stackTrace,
  );
  final buffer = StringBuffer('[TreeSitter] $message');
  if (error != null) {
    buffer.write(' | $error');
  }
  if (stackTrace != null) {
    buffer.write('\n$stackTrace');
  }
  // ignore: avoid_print
  print(buffer.toString());
}

Map<String, String> _githubHeaders() {
  final headers = <String, String>{'Accept': 'application/vnd.github+json'};
  final token = Platform.environment['GITHUB_TOKEN'];
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }
  return headers;
}
