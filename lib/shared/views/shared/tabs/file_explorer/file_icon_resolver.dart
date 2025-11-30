import 'package:flutter/widgets.dart';

import '../../../../../models/remote_file_entry.dart';
import '../../../../theme/nerd_fonts.dart';

class FileIconResolver {
  const FileIconResolver._();

  static IconData iconFor(RemoteFileEntry entry) {
    if (entry.isDirectory) {
      return NerdIcon.folder.data;
    }
    final lower = entry.name.toLowerCase();
    final exactMatch = _nameIcons[lower];
    if (exactMatch != null) {
      return exactMatch.data;
    }
    final baseName = _baseNameOf(lower);
    final baseMatch = _baseNameIcons[baseName];
    if (baseMatch != null) {
      return baseMatch.data;
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
    'json': NerdIcon.json,
    'json5': NerdIcon.json,
    'ndjson': NerdIcon.json,
    'geojson': NerdIcon.json,
    'har': NerdIcon.json,
    'md': NerdIcon.markdown,
    'markdown': NerdIcon.markdown,
    'adoc': NerdIcon.markdown,
    'rst': NerdIcon.markdown,
    'org': NerdIcon.markdown,
    'txt': NerdIcon.fileCode,
    'log': NerdIcon.fileCode,
    'py': NerdIcon.python,
    'pyw': NerdIcon.python,
    'ipynb': NerdIcon.python,
    'rb': NerdIcon.ruby,
    'rs': NerdIcon.rust,
    'ron': NerdIcon.rust,
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
}
