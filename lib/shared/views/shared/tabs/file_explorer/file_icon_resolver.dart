import 'package:flutter/material.dart';

import '../../../../../models/remote_file_entry.dart';
import '../../../../theme/nerd_fonts.dart';

class FileIconResolver {
  const FileIconResolver._();

  static IconData iconFor(RemoteFileEntry entry) {
    if (entry.isDirectory) {
      return NerdIcon.folder.data;
    }
    final lower = entry.name.toLowerCase();
    final isHidden = entry.name.startsWith('.');
    final exactMatch = _nameIcons[lower];
    if (exactMatch != null) {
      return exactMatch.data;
    }
    final baseName = _baseNameOf(lower);
    final baseMatch = _baseNameIcons[baseName];
    if (baseMatch != null) {
      return baseMatch.data;
    }
    if (_isShellDotfile(baseName, isHidden: isHidden)) {
      return NerdIcon.terminal.data;
    }
    final compound = _compoundExtensionIcon(lower);
    if (compound != null) {
      return compound.data;
    }
    final ext = _extensionOf(lower);
    if (ext != null) {
      final icon = _extensionIcons[ext];
      if (icon != null) {
        return icon.data;
      }
    }
    return NerdIcon.fileCode.data;
  }

  static Color colorFor(RemoteFileEntry entry, ColorScheme scheme) {
    if (entry.isDirectory) {
      return _colorForCategory(_IconCategory.folder, scheme);
    }
    final lower = entry.name.toLowerCase();
    final isHidden = entry.name.startsWith('.');
    final nameCategory = _categoryForExact(lower);
    if (nameCategory != null) {
      return _colorForCategory(nameCategory, scheme);
    }

    final baseName = _baseNameOf(lower);
    final baseCategory = _categoryForBase(baseName);
    if (baseCategory != null) {
      return _colorForCategory(baseCategory, scheme);
    }
    if (_isShellDotfile(baseName, isHidden: isHidden)) {
      return _colorForCategory(_IconCategory.terminal, scheme);
    }

    final compoundExt = _compoundExtensionOf(lower);
    if (compoundExt != null) {
      final compoundCategory = _categoryForExtension(compoundExt);
      if (compoundCategory != null) {
        return _colorForCategory(compoundCategory, scheme);
      }
    }

    final ext = _extensionOf(lower);
    final category = _categoryForExtension(ext);
    return _colorForCategory(category, scheme);
  }

  static String _baseNameOf(String name) {
    if (name.startsWith('.')) {
      name = name.substring(1);
    }
    final index = name.indexOf('.');
    if (index <= 0) {
      return name;
    }
    return name.substring(0, index);
  }

  static String? _extensionOf(String name) {
    final index = name.lastIndexOf('.');
    if (index <= 0 || index == name.length - 1) {
      return null;
    }
    return name.substring(index + 1);
  }

  static NerdIcon? _compoundExtensionIcon(String name) {
    for (final entry in _compoundExtensionIcons.entries) {
      if (name.endsWith('.${entry.key}')) {
        return entry.value;
      }
    }
    return null;
  }

  static String? _compoundExtensionOf(String name) {
    for (final entry in _compoundExtensionIcons.entries) {
      if (name.endsWith('.${entry.key}')) {
        return entry.key;
      }
    }
    return null;
  }

  static bool _isShellDotfile(String base, {required bool isHidden}) {
    if (!isHidden) return false;
    for (final prefix in _shellDotfilePrefixes) {
      if (base.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  static const Map<String, NerdIcon> _nameIcons = {
    'dockerfile': NerdIcon.docker,
    'compose.yaml': NerdIcon.docker,
    'compose.yml': NerdIcon.docker,
    'go.mod': NerdIcon.go,
    'go.sum': NerdIcon.go,
    'analysis_options.yaml': NerdIcon.dart,
    'pubspec.yaml': NerdIcon.dart,
    'package.json': NerdIcon.json,
    'pnpm-lock.yaml': NerdIcon.json,
    'bun.lockb': NerdIcon.json,
    'tsconfig.json': NerdIcon.typescript,
    'jsconfig.json': NerdIcon.javascript,
    'docker-compose.yaml': NerdIcon.docker,
    'docker-compose.yml': NerdIcon.docker,
    'devcontainer.json': NerdIcon.docker,
    '.bashrc': NerdIcon.terminal,
    '.bash_profile': NerdIcon.terminal,
    '.bash_logout': NerdIcon.terminal,
    '.bash_history': NerdIcon.terminal,
    '.bash_aliases': NerdIcon.terminal,
    '.bash_functions': NerdIcon.terminal,
    '.bash_completion': NerdIcon.terminal,
    '.zshrc': NerdIcon.terminal,
    '.zprofile': NerdIcon.terminal,
    '.zlogin': NerdIcon.terminal,
    '.zlogout': NerdIcon.terminal,
    '.zshenv': NerdIcon.terminal,
    '.zsh_history': NerdIcon.terminal,
    '.profile': NerdIcon.terminal,
    '.pylintrc': NerdIcon.python,
    '.pypirc': NerdIcon.python,
    '.pythonrc': NerdIcon.python,
    '.python_history': NerdIcon.python,
  };

  static const Map<String, _IconCategory> _nameCategories = {
    'dockerfile': _IconCategory.docker,
    'compose.yaml': _IconCategory.docker,
    'compose.yml': _IconCategory.docker,
    'docker-compose.yaml': _IconCategory.docker,
    'docker-compose.yml': _IconCategory.docker,
    'devcontainer.json': _IconCategory.docker,
    'go.mod': _IconCategory.code,
    'go.sum': _IconCategory.code,
    'go.work': _IconCategory.config,
    'go.work.sum': _IconCategory.config,
    'analysis_options.yaml': _IconCategory.config,
    'pubspec.yaml': _IconCategory.config,
    'package.json': _IconCategory.config,
    'pnpm-lock.yaml': _IconCategory.lock,
    'bun.lockb': _IconCategory.lock,
    'tsconfig.json': _IconCategory.config,
    'jsconfig.json': _IconCategory.config,
    'devcontainer': _IconCategory.docker,
    'build.gradle': _IconCategory.config,
    'settings.gradle': _IconCategory.config,
    'build.gradle.kts': _IconCategory.config,
    'settings.gradle.kts': _IconCategory.config,
    '.bashrc': _IconCategory.terminal,
    '.bash_profile': _IconCategory.terminal,
    '.bash_logout': _IconCategory.terminal,
    '.bash_history': _IconCategory.terminal,
    '.bash_aliases': _IconCategory.terminal,
    '.bash_functions': _IconCategory.terminal,
    '.bash_completion': _IconCategory.terminal,
    '.zshrc': _IconCategory.terminal,
    '.zprofile': _IconCategory.terminal,
    '.zlogin': _IconCategory.terminal,
    '.zlogout': _IconCategory.terminal,
    '.zshenv': _IconCategory.terminal,
    '.zsh_history': _IconCategory.terminal,
    '.profile': _IconCategory.terminal,
    '.pylintrc': _IconCategory.code,
    '.pypirc': _IconCategory.code,
    '.pythonrc': _IconCategory.code,
    '.python_history': _IconCategory.code,
  };

  static const Map<String, NerdIcon> _baseNameIcons = {
    'readme': NerdIcon.markdown,
    'license': NerdIcon.lock,
    'copying': NerdIcon.lock,
    'changelog': NerdIcon.markdown,
    'todo': NerdIcon.markdown,
    'authors': NerdIcon.markdown,
    'package': NerdIcon.json,
    'package-lock': NerdIcon.json,
    'pnpm-lock': NerdIcon.json,
    'yarn': NerdIcon.json,
    'yarnrc': NerdIcon.javascript,
    'npmrc': NerdIcon.javascript,
    'tsconfig': NerdIcon.typescript,
    'jsconfig': NerdIcon.javascript,
    'devcontainer': NerdIcon.docker,
    'babelrc': NerdIcon.javascript,
    'eslintrc': NerdIcon.javascript,
    'prettierrc': NerdIcon.json,
    'stylelintrc': NerdIcon.css3,
    'eslintignore': NerdIcon.settings,
    'stylelintignore': NerdIcon.settings,
    'editorconfig': NerdIcon.config,
    'gitignore': NerdIcon.settings,
    'gitattributes': NerdIcon.settings,
    'gitmodules': NerdIcon.settings,
    'dockerignore': NerdIcon.docker,
    'env': NerdIcon.config,
    'envrc': NerdIcon.config,
    'bunfig': NerdIcon.javascript,
    'gradlew': NerdIcon.terminal,
    'mvnw': NerdIcon.terminal,
    'justfile': NerdIcon.terminal,
    'makefile': NerdIcon.settings,
    'rakefile': NerdIcon.ruby,
    'vagrantfile': NerdIcon.settings,
    'tiltfile': NerdIcon.settings,
    'containerfile': NerdIcon.docker,
    'procfile': NerdIcon.terminal,
    'podfile': NerdIcon.swift,
    'gemfile': NerdIcon.ruby,
    'cargo': NerdIcon.rust,
    'pipfile': NerdIcon.python,
    'requirements': NerdIcon.python,
    'pip': NerdIcon.python,
    'pipenv': NerdIcon.python,
    'pyproject': NerdIcon.python,
    'poetry': NerdIcon.python,
    'flake8': NerdIcon.python,
    'ruff': NerdIcon.python,
    'hushlogin': NerdIcon.terminal,
    'bashrc': NerdIcon.terminal,
    'bash_profile': NerdIcon.terminal,
    'bash_logout': NerdIcon.terminal,
    'bash_history': NerdIcon.terminal,
    'bash_aliases': NerdIcon.terminal,
    'bash_functions': NerdIcon.terminal,
    'bash_completion': NerdIcon.terminal,
    'zsh_history': NerdIcon.terminal,
    'profile': NerdIcon.terminal,
    'zshrc': NerdIcon.terminal,
    'zprofile': NerdIcon.terminal,
    'zlogin': NerdIcon.terminal,
    'zlogout': NerdIcon.terminal,
    'zshenv': NerdIcon.terminal,
    'vimrc': NerdIcon.terminal,
    'tmux': NerdIcon.terminal,
    'fzf': NerdIcon.terminal,
    'lesshst': NerdIcon.terminal,
    'nvimrc': NerdIcon.terminal,
    'viminfo': NerdIcon.terminal,
    'ssh': NerdIcon.lock,
    'hosts': NerdIcon.lock,
    'ssh_config': NerdIcon.lock,
    'sshd_config': NerdIcon.lock,
    'known_hosts': NerdIcon.lock,
    'authorized_keys': NerdIcon.lock,
    'netrc': NerdIcon.lock,
    'xauthority': NerdIcon.lock,
    'gitconfig': NerdIcon.settings,
    'gitmessage': NerdIcon.settings,
    'gitignore_global': NerdIcon.settings,
    'sdkman': NerdIcon.java,
    'krew': NerdIcon.kubernetes,
    'terminfo': NerdIcon.settings,
    'wget-hsts': NerdIcon.config,
    'flake': NerdIcon.config,
    'tool-versions': NerdIcon.settings,
    'direnv': NerdIcon.config,
    'nvmrc': NerdIcon.javascript,
    'node-version': NerdIcon.javascript,
    'yarn-version': NerdIcon.javascript,
    'ruby-version': NerdIcon.ruby,
    'python-version': NerdIcon.python,
    'java-version': NerdIcon.java,
    'go-version': NerdIcon.go,
    'gradle-wrapper': NerdIcon.config,
    'mkdocs': NerdIcon.markdown,
    'pom': NerdIcon.config,
    'dockerfile': NerdIcon.docker,
  };

  static const Map<String, _IconCategory> _baseNameCategories = {
    'readme': _IconCategory.text,
    'license': _IconCategory.lock,
    'copying': _IconCategory.lock,
    'changelog': _IconCategory.text,
    'todo': _IconCategory.text,
    'authors': _IconCategory.text,
    'package': _IconCategory.config,
    'package-lock': _IconCategory.lock,
    'pnpm-lock': _IconCategory.lock,
    'yarn': _IconCategory.config,
    'yarnrc': _IconCategory.config,
    'npmrc': _IconCategory.config,
    'tsconfig': _IconCategory.config,
    'jsconfig': _IconCategory.config,
    'devcontainer': _IconCategory.docker,
    'babelrc': _IconCategory.config,
    'eslintrc': _IconCategory.config,
    'prettierrc': _IconCategory.config,
    'stylelintrc': _IconCategory.config,
    'eslintignore': _IconCategory.config,
    'stylelintignore': _IconCategory.config,
    'editorconfig': _IconCategory.config,
    'gitignore': _IconCategory.lock,
    'gitattributes': _IconCategory.lock,
    'gitmodules': _IconCategory.lock,
    'dockerignore': _IconCategory.docker,
    'env': _IconCategory.config,
    'envrc': _IconCategory.config,
    'bunfig': _IconCategory.config,
    'gradlew': _IconCategory.terminal,
    'mvnw': _IconCategory.terminal,
    'justfile': _IconCategory.terminal,
    'makefile': _IconCategory.terminal,
    'rakefile': _IconCategory.terminal,
    'vagrantfile': _IconCategory.terminal,
    'tiltfile': _IconCategory.terminal,
    'containerfile': _IconCategory.docker,
    'procfile': _IconCategory.terminal,
    'podfile': _IconCategory.code,
    'gemfile': _IconCategory.code,
    'cargo': _IconCategory.code,
    'pipfile': _IconCategory.config,
    'requirements': _IconCategory.config,
    'pip': _IconCategory.config,
    'pipenv': _IconCategory.config,
    'pyproject': _IconCategory.config,
    'poetry': _IconCategory.config,
    'flake8': _IconCategory.config,
    'ruff': _IconCategory.config,
    'hushlogin': _IconCategory.lock,
    'bashrc': _IconCategory.terminal,
    'bash_profile': _IconCategory.terminal,
    'bash_logout': _IconCategory.terminal,
    'bash_history': _IconCategory.terminal,
    'bash_aliases': _IconCategory.terminal,
    'bash_functions': _IconCategory.terminal,
    'bash_completion': _IconCategory.terminal,
    'zsh_history': _IconCategory.terminal,
    'profile': _IconCategory.terminal,
    'zshrc': _IconCategory.terminal,
    'zprofile': _IconCategory.terminal,
    'zlogin': _IconCategory.terminal,
    'zlogout': _IconCategory.terminal,
    'zshenv': _IconCategory.terminal,
    'vimrc': _IconCategory.terminal,
    'tmux': _IconCategory.terminal,
    'fzf': _IconCategory.terminal,
    'lesshst': _IconCategory.terminal,
    'nvimrc': _IconCategory.terminal,
    'viminfo': _IconCategory.terminal,
    'ssh': _IconCategory.lock,
    'hosts': _IconCategory.lock,
    'ssh_config': _IconCategory.lock,
    'sshd_config': _IconCategory.lock,
    'known_hosts': _IconCategory.lock,
    'authorized_keys': _IconCategory.lock,
    'netrc': _IconCategory.lock,
    'xauthority': _IconCategory.lock,
    'gitconfig': _IconCategory.config,
    'gitmessage': _IconCategory.config,
    'gitignore_global': _IconCategory.config,
    'sdkman': _IconCategory.config,
    'krew': _IconCategory.docker,
    'terminfo': _IconCategory.config,
    'wget-hsts': _IconCategory.lock,
    'flake': _IconCategory.config,
    'tool-versions': _IconCategory.config,
    'direnv': _IconCategory.config,
    'nvmrc': _IconCategory.config,
    'node-version': _IconCategory.config,
    'yarn-version': _IconCategory.config,
    'ruby-version': _IconCategory.config,
    'python-version': _IconCategory.config,
    'java-version': _IconCategory.config,
    'go-version': _IconCategory.config,
    'gradle-wrapper': _IconCategory.config,
    'mkdocs': _IconCategory.text,
    'pom': _IconCategory.config,
    'dockerfile': _IconCategory.docker,
    'cmakelists': _IconCategory.config,
    'brewfile': _IconCategory.config,
    'go.work': _IconCategory.config,
    'go.work.sum': _IconCategory.config,
  };

  static const Map<String, NerdIcon> _compoundExtensionIcons = {
    'tar.gz': NerdIcon.settings,
    'tar.bz2': NerdIcon.settings,
    'tar.xz': NerdIcon.settings,
    'tar.zst': NerdIcon.settings,
    'd.ts': NerdIcon.typescript,
    'test.tsx': NerdIcon.typescript,
    'test.ts': NerdIcon.typescript,
    'spec.tsx': NerdIcon.typescript,
    'spec.ts': NerdIcon.typescript,
    'test.js': NerdIcon.javascript,
    'spec.js': NerdIcon.javascript,
  };

  static final Map<String, NerdIcon> _extensionIcons = {
    'dart': NerdIcon.dart,
    'js': NerdIcon.javascript,
    'jsx': NerdIcon.javascript,
    'mjs': NerdIcon.javascript,
    'cjs': NerdIcon.javascript,
    'ts': NerdIcon.typescript,
    'tsx': NerdIcon.typescript,
    'vue': NerdIcon.javascript,
    'svelte': NerdIcon.javascript,
    'astro': NerdIcon.javascript,
    'css': NerdIcon.css3,
    'scss': NerdIcon.css3,
    'less': NerdIcon.css3,
    'html': NerdIcon.html5,
    'htm': NerdIcon.html5,
    'yaml': NerdIcon.yaml,
    'yml': NerdIcon.yaml,
    'toml': NerdIcon.config,
    'ini': NerdIcon.config,
    'cfg': NerdIcon.config,
    'conf': NerdIcon.config,
    'env': NerdIcon.config,
    'properties': NerdIcon.config,
    'props': NerdIcon.config,
    'targets': NerdIcon.config,
    'nix': NerdIcon.config,
    'gradle': NerdIcon.config,
    'hcl': NerdIcon.config,
    'tf': NerdIcon.config,
    'tfvars': NerdIcon.config,
    'tfstate': NerdIcon.config,
    'cue': NerdIcon.config,
    'xml': NerdIcon.config,
    'json': NerdIcon.json,
    'json5': NerdIcon.json,
    'ndjson': NerdIcon.json,
    'geojson': NerdIcon.json,
    'har': NerdIcon.json,
    'plist': NerdIcon.config,
    'csproj': NerdIcon.config,
    'vbproj': NerdIcon.config,
    'sln': NerdIcon.config,
    'md': NerdIcon.markdown,
    'markdown': NerdIcon.markdown,
    'adoc': NerdIcon.markdown,
    'rst': NerdIcon.markdown,
    'org': NerdIcon.markdown,
    'txt': NerdIcon.fileCode,
    'log': NerdIcon.fileCode,
    'py': NerdIcon.python,
    'pyw': NerdIcon.python,
    'pyi': NerdIcon.python,
    'pyc': NerdIcon.python,
    'pyd': NerdIcon.python,
    'pyx': NerdIcon.python,
    'pxd': NerdIcon.python,
    'pxi': NerdIcon.python,
    'pyo': NerdIcon.python,
    'ipynb': NerdIcon.python,
    'rb': NerdIcon.ruby,
    'rs': NerdIcon.rust,
    'ron': NerdIcon.rust,
    'hs': NerdIcon.settings,
    'lhs': NerdIcon.settings,
    'cabal': NerdIcon.settings,
    'fs': NerdIcon.settings,
    'fsi': NerdIcon.settings,
    'fsx': NerdIcon.settings,
    'clj': NerdIcon.settings,
    'cljs': NerdIcon.settings,
    'edn': NerdIcon.settings,
    'erl': NerdIcon.settings,
    'hrl': NerdIcon.settings,
    'ex': NerdIcon.settings,
    'exs': NerdIcon.settings,
    'eex': NerdIcon.settings,
    'heex': NerdIcon.settings,
    'zig': NerdIcon.fileCode,
    'swift': NerdIcon.swift,
    'kt': NerdIcon.kotlin,
    'kts': NerdIcon.kotlin,
    'java': NerdIcon.java,
    'c': NerdIcon.c,
    'h': NerdIcon.c,
    'cpp': NerdIcon.cpp,
    'cc': NerdIcon.cpp,
    'cxx': NerdIcon.cpp,
    'hpp': NerdIcon.cpp,
    'hh': NerdIcon.cpp,
    'cs': NerdIcon.csharp,
    'go': NerdIcon.go,
    'php': NerdIcon.php,
    'hack': NerdIcon.php,
    'scala': NerdIcon.java,
    'groovy': NerdIcon.java,
    'lua': NerdIcon.settings,
    'm': NerdIcon.cpp,
    'mm': NerdIcon.cpp,
    'objc': NerdIcon.cpp,
    'swiftinterface': NerdIcon.swift,
    'sql': NerdIcon.database,
    'db': NerdIcon.database,
    'psql': NerdIcon.database,
    'sqlite': NerdIcon.database,
    'sqlite3': NerdIcon.database,
    'db3': NerdIcon.database,
    'csv': NerdIcon.database,
    'tsv': NerdIcon.database,
    'parquet': NerdIcon.database,
    'proto': NerdIcon.database,
    'graphql': NerdIcon.database,
    'dockerignore': NerdIcon.docker,
    'sh': NerdIcon.terminal,
    'bash': NerdIcon.terminal,
    'zsh': NerdIcon.terminal,
    'fish': NerdIcon.terminal,
    'ksh': NerdIcon.terminal,
    'csh': NerdIcon.terminal,
    'tcsh': NerdIcon.terminal,
    'ash': NerdIcon.terminal,
    'dash': NerdIcon.terminal,
    'pwsh': NerdIcon.terminal,
    'xonsh': NerdIcon.terminal,
    'shell': NerdIcon.terminal,
    'ps1': NerdIcon.terminal,
    'cmd': NerdIcon.terminal,
    'bat': NerdIcon.terminal,
    'nushell': NerdIcon.terminal,
    'psm1': NerdIcon.terminal,
    'psd1': NerdIcon.terminal,
    'lock': NerdIcon.lock,
    'lockb': NerdIcon.lock,
    'lockfile': NerdIcon.lock,
    'sum': NerdIcon.go,
    'mod': NerdIcon.go,
    'pem': NerdIcon.lock,
    'crt': NerdIcon.lock,
    'key': NerdIcon.lock,
    'cer': NerdIcon.lock,
    'pub': NerdIcon.lock,
    'pfx': NerdIcon.lock,
    'p12': NerdIcon.lock,
    'csr': NerdIcon.lock,
    'png': NerdIcon.fileImage,
    'jpg': NerdIcon.fileImage,
    'jpeg': NerdIcon.fileImage,
    'gif': NerdIcon.fileImage,
    'svg': NerdIcon.fileImage,
    'webp': NerdIcon.fileImage,
    'ico': NerdIcon.fileImage,
    'avif': NerdIcon.fileImage,
    'bmp': NerdIcon.fileImage,
    'psd': NerdIcon.fileImage,
    'heic': NerdIcon.fileImage,
    'heif': NerdIcon.fileImage,
    'tiff': NerdIcon.fileImage,
    'tif': NerdIcon.fileImage,
    'dds': NerdIcon.fileImage,
    'ai': NerdIcon.fileImage,
    'eps': NerdIcon.fileImage,
    'indd': NerdIcon.fileImage,
    'zip': NerdIcon.settings,
    'tgz': NerdIcon.settings,
    'gz': NerdIcon.settings,
    'bz2': NerdIcon.settings,
    'xz': NerdIcon.settings,
    'zst': NerdIcon.settings,
    'rar': NerdIcon.settings,
    '7z': NerdIcon.settings,
    'apk': NerdIcon.settings,
    'ipa': NerdIcon.settings,
    'img': NerdIcon.settings,
    'iso': NerdIcon.settings,
    'wasm': NerdIcon.settings,
    'deb': NerdIcon.settings,
    'rpm': NerdIcon.settings,
    'bin': NerdIcon.settings,
    'exe': NerdIcon.settings,
    'dll': NerdIcon.settings,
    'dylib': NerdIcon.settings,
    'so': NerdIcon.settings,
    'a': NerdIcon.settings,
    'o': NerdIcon.settings,
    'bundle': NerdIcon.settings,
    'appimage': NerdIcon.settings,
  };

  static const Set<String> _codeExtensions = {
    'dart',
    'js',
    'jsx',
    'mjs',
    'cjs',
    'ts',
    'tsx',
    'vue',
    'svelte',
    'astro',
    'py',
    'pyw',
    'pyi',
    'pyc',
    'pyd',
    'pyx',
    'pxd',
    'pxi',
    'pyo',
    'ipynb',
    'rb',
    'rs',
    'ron',
    'hs',
    'lhs',
    'cabal',
    'fs',
    'fsi',
    'fsx',
    'clj',
    'cljs',
    'edn',
    'erl',
    'hrl',
    'ex',
    'exs',
    'eex',
    'heex',
    'zig',
    'swift',
    'kt',
    'kts',
    'java',
    'c',
    'h',
    'cpp',
    'cc',
    'cxx',
    'hpp',
    'hh',
    'cs',
    'go',
    'php',
    'hack',
    'scala',
    'groovy',
    'lua',
    'm',
    'mm',
    'objc',
    'swiftinterface',
    'sql',
    'graphql',
    'sh',
    'bash',
    'zsh',
    'fish',
    'ksh',
    'csh',
    'tcsh',
    'ash',
    'dash',
    'pwsh',
    'xonsh',
    'shell',
    'ps1',
    'cmd',
    'bat',
    'nushell',
    'psm1',
    'psd1',
    'proto',
    'gradle',
    'wasm',
  };

  static const Set<String> _configExtensions = {
    'yaml',
    'yml',
    'toml',
    'ini',
    'cfg',
    'conf',
    'env',
    'properties',
    'props',
    'targets',
    'nix',
    'hcl',
    'tf',
    'tfvars',
    'tfstate',
    'cue',
    'xml',
    'csproj',
    'vbproj',
    'sln',
    'plist',
    'json',
    'json5',
    'ndjson',
    'geojson',
    'har',
    'lock',
    'lockb',
    'lockfile',
    'sum',
    'mod',
    'pem',
    'crt',
    'key',
    'cer',
    'pub',
    'pfx',
    'p12',
    'csr',
    'dockerignore',
  };

  static const Set<String> _textExtensions = {
    'md',
    'markdown',
    'adoc',
    'rst',
    'org',
    'txt',
    'log',
  };

  static const Set<String> _archiveExtensions = {
    'zip',
    'rar',
    '7z',
    'tar',
    'tgz',
    'gz',
    'bz2',
    'xz',
    'zst',
    'tar.gz',
    'tar.bz2',
    'tar.xz',
    'tar.zst',
    'apk',
    'ipa',
    'img',
    'iso',
    'deb',
    'rpm',
    'bin',
    'exe',
    'dll',
    'dylib',
    'so',
    'a',
    'o',
    'bundle',
    'appimage',
  };

  static const Set<String> _imageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'svg',
    'webp',
    'ico',
    'avif',
    'bmp',
    'psd',
    'heic',
    'heif',
    'tiff',
    'tif',
    'dds',
    'ai',
    'eps',
    'indd',
  };

  static _IconCategory? _categoryForExact(String name) {
    return _nameCategories[name];
  }

  static _IconCategory? _categoryForBase(String base) {
    return _baseNameCategories[base];
  }

  static _IconCategory? _categoryForExtension(String? ext) {
    if (ext == null) return _IconCategory.neutral;
    if (_codeExtensions.contains(ext)) return _IconCategory.code;
    if (_configExtensions.contains(ext)) return _IconCategory.config;
    if (_textExtensions.contains(ext)) return _IconCategory.text;
    if (_archiveExtensions.contains(ext)) return _IconCategory.archive;
    if (_imageExtensions.contains(ext)) return _IconCategory.image;
    if (_dataExtensions.contains(ext)) return _IconCategory.data;
    if (_lockExtensions.contains(ext)) return _IconCategory.lock;
    if (_terminalExtensions.contains(ext)) return _IconCategory.terminal;
    return _IconCategory.neutral;
  }

  static Color _colorForCategory(_IconCategory? category, ColorScheme scheme) {
    switch (category) {
      case _IconCategory.folder:
        return scheme.primary;
      case _IconCategory.code:
        return scheme.secondary;
      case _IconCategory.config:
        return scheme.tertiary;
      case _IconCategory.text:
        return scheme.primaryContainer;
      case _IconCategory.archive:
        return scheme.errorContainer;
      case _IconCategory.image:
        return scheme.secondaryContainer;
      case _IconCategory.data:
        return scheme.tertiaryContainer;
      case _IconCategory.lock:
        return scheme.error;
      case _IconCategory.terminal:
        return scheme.secondary;
      case _IconCategory.docker:
        return scheme.secondary;
      case _IconCategory.neutral:
      default:
        return scheme.onSurfaceVariant;
    }
  }

  static const Set<String> _dataExtensions = {
    'sql',
    'db',
    'psql',
    'sqlite',
    'sqlite3',
    'db3',
    'csv',
    'tsv',
    'parquet',
    'proto',
    'graphql',
  };

  static const Set<String> _lockExtensions = {
    'lock',
    'lockb',
    'lockfile',
    'pem',
    'crt',
    'key',
    'cer',
    'pub',
    'pfx',
    'p12',
    'csr',
  };

  static const Set<String> _terminalExtensions = {
    'sh',
    'bash',
    'zsh',
    'fish',
    'ksh',
    'csh',
    'tcsh',
    'ash',
    'dash',
    'pwsh',
    'xonsh',
    'shell',
    'ps1',
    'cmd',
    'bat',
    'nushell',
    'psm1',
    'psd1',
  };

  static const List<String> _shellDotfilePrefixes = [
    'bash',
    'zsh',
    'fish',
    'ksh',
    'csh',
    'tcsh',
    'xonsh',
    'pwsh',
  ];
}

enum _IconCategory {
  folder,
  code,
  config,
  text,
  archive,
  image,
  data,
  lock,
  terminal,
  docker,
  neutral,
}
