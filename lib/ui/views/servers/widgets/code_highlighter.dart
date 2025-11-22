import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' as hl;

class CodeHighlightTheme {
  const CodeHighlightTheme({
    required this.keyword,
    required this.function,
    required this.type,
    required this.string,
    required this.comment,
    required this.number,
  });

  factory CodeHighlightTheme.fromScheme(ColorScheme scheme) {
    // Use more visible colors for syntax highlighting
    final isDark = scheme.brightness == Brightness.dark;
    return CodeHighlightTheme(
      keyword: isDark ? scheme.primary : scheme.primary,
      function: isDark ? scheme.secondary : scheme.secondary,
      type: isDark ? scheme.tertiary : scheme.tertiary,
      string: isDark ? const Color(0xFF98C379) : const Color(0xFF22863A), // Green for strings
      comment: isDark ? const Color(0xFF6A737D) : const Color(0xFF6A737D), // Gray for comments
      number: isDark ? const Color(0xFF79B8FF) : const Color(0xFF005CC5), // Blue for numbers
    );
  }

  final Color keyword;
  final Color function;
  final Color type;
  final Color string;
  final Color comment;
  final Color number;
}

abstract class CodeSyntaxHighlighter {
  List<TextSpan> highlight(String source, TextStyle? baseStyle);
}

class PlainCodeHighlighter implements CodeSyntaxHighlighter {
  @override
  List<TextSpan> highlight(String source, TextStyle? baseStyle) {
    return [TextSpan(text: source, style: baseStyle)];
  }
}

class HighlightSyntaxHighlighter implements CodeSyntaxHighlighter {
  HighlightSyntaxHighlighter({
    required this.language,
    required this.theme,
  });

  final String? language;
  final CodeHighlightTheme theme;

  @override
  List<TextSpan> highlight(String source, TextStyle? baseStyle) {
    if (source.isEmpty || language == null) {
      return [TextSpan(text: source, style: baseStyle)];
    }

    // For Java and bash, always use fallback highlighting as it's more reliable
    if (language == 'java' || language == 'bash') {
      return _fallbackHighlight(source, baseStyle);
    }

    try {
      final result = hl.highlight.parse(source, language: language!);
      if (result.nodes == null || result.nodes!.isEmpty) {
        // Fallback: try basic regex-based highlighting if package fails
        return _fallbackHighlight(source, baseStyle);
      }

      // Check if we actually got any meaningful nodes with values
      bool hasContent = false;
      void checkContent(hl.Node node) {
        if (node.value != null && node.value!.isNotEmpty) {
          hasContent = true;
          return;
        }
        if (node.children != null) {
          for (final child in node.children!) {
            checkContent(child);
          }
        }
      }
      for (final node in result.nodes!) {
        checkContent(node);
      }
      if (!hasContent) {
        return _fallbackHighlight(source, baseStyle);
      }

      final spans = <TextSpan>[];
      void visit(hl.Node node) {
        // Process node value if it exists
        if (node.value != null && node.value!.isNotEmpty) {
          final style = _styleForClass(node.className, baseStyle);
          spans.add(TextSpan(text: node.value, style: style));
        }
        // Always visit children to ensure we don't miss any text
        if (node.children != null && node.children!.isNotEmpty) {
          for (final child in node.children!) {
            visit(child);
          }
        } else if (node.value == null || node.value!.isEmpty) {
          // If node has no value and no children, it might be a container
          // Check if we need to handle this case
        }
      }

      for (final node in result.nodes!) {
        visit(node);
      }

      // If we didn't get any spans, return plain text
      if (spans.isEmpty) {
        return [TextSpan(text: source, style: baseStyle)];
      }

      // Merge adjacent spans with the same style to improve performance
      final merged = <TextSpan>[];
      TextSpan? currentSpan;
      for (final span in spans) {
        if (currentSpan == null) {
          currentSpan = span;
        } else if (_spansHaveSameStyle(currentSpan, span)) {
          // Merge spans with same style
          currentSpan = TextSpan(
            text: (currentSpan.text ?? '') + (span.text ?? ''),
            style: currentSpan.style,
          );
        } else {
          merged.add(currentSpan);
          currentSpan = span;
        }
      }
      if (currentSpan != null) {
        merged.add(currentSpan);
      }

      // If merged result is empty or only has one span with no styling, use fallback
      if (merged.isEmpty || (merged.length == 1 && merged.first.style?.color == null)) {
        return _fallbackHighlight(source, baseStyle);
      }

      return merged;
    } catch (e) {
      // Fallback to basic highlighting on error
      return _fallbackHighlight(source, baseStyle);
    }
  }

  List<TextSpan> _fallbackHighlight(String source, TextStyle? baseStyle) {
    // Simple regex-based fallback highlighting for Java-like syntax
    // Always use fallback for supported languages
    final supportedLanguages = ['java', 'dart', 'javascript', 'typescript', 'cpp', 'c', 'csharp', 'bash'];
    if (language == null || !supportedLanguages.contains(language!)) {
      return [TextSpan(text: source, style: baseStyle)];
    }

    final spans = <TextSpan>[];
    
    // Different keyword patterns for different languages
    RegExp keywordPattern;
    if (language == 'bash') {
      // Bash keywords - using word boundaries and common bash constructs
      keywordPattern = RegExp(r'\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|select|until|break|continue|return|exit|export|local|readonly|declare|typeset|alias|source|echo|printf|test|read|exec|eval|set|unset|shift|trap|wait|true|false|null|cd|pwd|ls|grep|find|cat|sed|awk|sort|uniq|wc|head|tail|mkdir|rm|cp|mv|chmod|chown|sudo|su)\b');
    } else {
      // Java/other language keywords
      keywordPattern = RegExp(r'\b(public|private|protected|static|final|class|interface|extends|implements|if|else|for|while|return|void|int|String|boolean|double|float|long|char|byte|short|null|true|false|new|this|super|import|package)\b');
    }
    
    // String patterns - bash uses both single and double quotes, and $var expansion
    RegExp stringPattern;
    if (language == 'bash') {
      // Bash strings: "text", 'text', and $variable expansions
      stringPattern = RegExp(r'''("([^"\\]|\\.)*"|'([^'\\]|\\.)*'|\$\{?[a-zA-Z_][a-zA-Z0-9_]*\}?)''');
    } else {
      stringPattern = RegExp(r'''("([^"\\]|\\.)*"|'([^'\\]|\\.)*')''');
    }
    
    // Comment patterns
    RegExp commentPattern;
    if (language == 'bash') {
      // Bash comments: # to end of line
      commentPattern = RegExp(r'#.*$', multiLine: true);
    } else {
      commentPattern = RegExp(r'(//.*$|/\*[\s\S]*?\*/)', multiLine: true);
    }
    
    final numberPattern = RegExp(r'\b\d+\.?\d*\b');

    int lastIndex = 0;
    final matches = <_Match>[];

    // Collect all matches
    for (final match in keywordPattern.allMatches(source)) {
      matches.add(_Match(match.start, match.end, 'keyword'));
    }
    for (final match in stringPattern.allMatches(source)) {
      matches.add(_Match(match.start, match.end, 'string'));
    }
    for (final match in commentPattern.allMatches(source)) {
      matches.add(_Match(match.start, match.end, 'comment'));
    }
    for (final match in numberPattern.allMatches(source)) {
      matches.add(_Match(match.start, match.end, 'number'));
    }

    // Sort by start position
    matches.sort((a, b) => a.start.compareTo(b.start));

    // Remove overlapping matches (keep first)
    final filtered = <_Match>[];
    for (final match in matches) {
      if (filtered.isEmpty || match.start >= filtered.last.end) {
        filtered.add(match);
      }
    }

    // Build spans
    for (final match in filtered) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: source.substring(lastIndex, match.start), style: baseStyle));
      }
      Color? color;
      switch (match.type) {
        case 'keyword':
          color = theme.keyword;
        case 'string':
          color = theme.string;
        case 'comment':
          color = theme.comment;
        case 'number':
          color = theme.number;
      }
      final style = color != null
          ? (baseStyle?.copyWith(color: color) ?? TextStyle(color: color))
          : baseStyle;
      spans.add(TextSpan(
        text: source.substring(match.start, match.end),
        style: style,
      ));
      lastIndex = match.end;
    }

    if (lastIndex < source.length) {
      spans.add(TextSpan(text: source.substring(lastIndex), style: baseStyle));
    }

    return spans.isEmpty ? [TextSpan(text: source, style: baseStyle)] : spans;
  }

  TextStyle? _styleForClass(String? className, TextStyle? baseStyle) {
    if (className == null || className.isEmpty) {
      return baseStyle;
    }

    Color? color;
    // Remove hljs- prefix if present and convert to lowercase
    // Also handle cases where className might be a list or have spaces
    final normalized = className
        .replaceAll('hljs-', '')
        .replaceAll('hljs.', '')
        .split(' ')
        .first
        .toLowerCase();

    // Map highlight.js classes to theme colors
    // Check for keywords first (most common in Java: public, class, static, etc.)
    if (normalized.contains('keyword') ||
        normalized == 'kw' ||
        normalized.contains('built_in') ||
        normalized.contains('operator') ||
        normalized == 'op' ||
        normalized == 'reserved') {
      color = theme.keyword;
    } 
    // Check for strings (Java: "text", 'c')
    else if (normalized.contains('string') ||
        normalized == 'str' ||
        normalized.contains('char') ||
        normalized == 'attr') {
      color = theme.string;
    } 
    // Check for comments (Java: // and /* */)
    else if (normalized.contains('comment') ||
        normalized == 'com' ||
        normalized == 'doctag') {
      color = theme.comment;
    } 
    // Check for numbers (Java: 123, 45.6)
    else if (normalized.contains('number') ||
        normalized == 'num' ||
        normalized.contains('literal') ||
        normalized == 'params') {
      color = theme.number;
    } 
    // Check for functions (Java: method names)
    else if (normalized.contains('function') ||
        normalized == 'fun' ||
        normalized.contains('title.function') ||
        normalized == 'title') {
      color = theme.function;
    } 
    // Check for types/classes (Java: class names, type names)
    else if (normalized.contains('type') ||
        normalized == 'typ' ||
        normalized.contains('class') ||
        normalized.contains('title.class') ||
        normalized == 'built_in') {
      color = theme.type;
    }

    if (color != null) {
      return baseStyle?.copyWith(color: color) ?? TextStyle(color: color);
    }
    return baseStyle;
  }

  bool _spansHaveSameStyle(TextSpan a, TextSpan b) {
    if (a.style == null && b.style == null) return true;
    if (a.style == null || b.style == null) return false;
    return a.style!.color == b.style!.color &&
        a.style!.fontWeight == b.style!.fontWeight &&
        a.style!.fontStyle == b.style!.fontStyle;
  }
}

class _Match {
  _Match(this.start, this.end, this.type);
  final int start;
  final int end;
  final String type;
}

/// Helper to get language identifier from file extension or path
String? languageFromPath(String path) {
  final fileName = path.split('/').lastOrNull?.toLowerCase() ?? '';
  
  // Handle special filenames (case-insensitive matching for common patterns)
  
  // Docker files
  if (fileName == 'dockerfile' || fileName.startsWith('dockerfile.')) {
    return 'dockerfile';
  }
  if (fileName == '.dockerignore') {
    return 'dockerfile';
  }
  
  // Makefile variants
  if (fileName == 'makefile' || fileName == 'gnumakefile' || fileName.startsWith('makefile.')) {
    return 'makefile';
  }
  
  // CMake files
  if (fileName == 'cmakelists.txt' || fileName.endsWith('.cmake')) {
    return 'cmake';
  }
  
  // Rakefile
  if (fileName == 'rakefile' || fileName == 'rakefile.rb') {
    return 'ruby';
  }
  
  // Gemfile
  if (fileName == 'gemfile' || fileName == 'gemfile.lock') {
    return 'ruby';
  }
  
  // Package files
  if (fileName == 'package.json' || fileName == 'package-lock.json') {
    return 'json';
  }
  if (fileName == 'composer.json' || fileName == 'composer.lock') {
    return 'json';
  }
  if (fileName == 'pom.xml' || fileName == 'build.xml') {
    return 'xml';
  }
  
  // Config files by name
  if (fileName == 'tsconfig.json' || fileName == 'jsconfig.json') {
    return 'json';
  }
  if (fileName == '.eslintrc' || fileName == '.eslintrc.json' || 
      fileName == '.eslintrc.js' || fileName == '.eslintrc.yml') {
    return fileName.endsWith('.yml') ? 'yaml' : (fileName.endsWith('.js') ? 'javascript' : 'json');
  }
  if (fileName == '.prettierrc' || fileName == '.prettierrc.json' ||
      fileName == '.prettierrc.js' || fileName == '.prettierrc.yml') {
    return fileName.endsWith('.yml') ? 'yaml' : (fileName.endsWith('.js') ? 'javascript' : 'json');
  }
  
  // Handle dotfiles (files starting with a dot)
  if (fileName.startsWith('.')) {
    if (fileName == '.bashrc' || 
        fileName == '.bash_profile' || 
        fileName == '.bash_aliases' ||
        fileName == '.bash_logout' ||
        fileName == '.zshrc' ||
        fileName == '.zprofile' ||
        fileName == '.zshenv' ||
        fileName == '.profile' ||
        fileName == '.shrc') {
      return 'bash';
    }
    if (fileName == '.gitconfig' || fileName == '.gitignore' || 
        fileName == '.gitattributes' || fileName == '.gitmodules') {
      return 'git';
    }
    if (fileName == '.vimrc' || fileName == '.vim' || fileName == '.gvimrc') {
      return 'vim';
    }
    if (fileName == '.editorconfig') {
      return 'ini';
    }
    if (fileName == '.env' || fileName.startsWith('.env.')) {
      return 'properties';
    }
    if (fileName == '.npmrc') {
      return 'ini';
    }
    if (fileName == '.yarnrc' || fileName == '.yarnrc.yml') {
      return fileName.endsWith('.yml') ? 'yaml' : 'yaml';
    }
    if (fileName == '.travis.yml' || fileName == '.github' && path.contains('workflows')) {
      return 'yaml';
    }
  }
  
  // Get all extensions (handle multiple extensions like file.min.js)
  final parts = fileName.split('.');
  if (parts.length < 2) {
    // No extension, check if it's a known filename
    return null;
  }
  
  // Check last extension first (most specific)
  final ext = parts.last.toLowerCase();
  final ext2 = parts.length > 2 ? parts[parts.length - 2].toLowerCase() : null;
  
  // Handle double extensions (e.g., .min.js, .d.ts)
  if (ext2 != null) {
    if ((ext2 == 'min' || ext2 == 'bundle') && ext == 'js') {
      return 'javascript';
    }
    if (ext2 == 'd' && ext == 'ts') {
      return 'typescript';
    }
    if (ext2 == 'component' && ext == 'ts') {
      return 'typescript';
    }
    if (ext2 == 'component' && ext == 'js') {
      return 'javascript';
    }
  }

  // Map common extensions to highlight.js language identifiers
  switch (ext) {
    // Web technologies
    case 'html':
    case 'htm':
      return 'xml';
    case 'xhtml':
    case 'xht':
      return 'xml';
    case 'xml':
    case 'xsl':
    case 'xslt':
    case 'xsd':
    case 'rss':
    case 'atom':
      return 'xml';
    case 'js':
    case 'jsx':
    case 'mjs':
    case 'cjs':
      return 'javascript';
    case 'ts':
    case 'tsx':
    case 'mts':
    case 'cts':
      return 'typescript';
    case 'css':
    case 'scss':
    case 'sass':
      return ext == 'scss' || ext == 'sass' ? 'scss' : 'css';
    case 'less':
      return 'less';
    case 'vue':
      return 'vue';
    
    // Programming languages
    case 'dart':
      return 'dart';
    case 'py':
    case 'pyw':
    case 'pyi':
      return 'python';
    case 'java':
    case 'class':
      return 'java';
    case 'c':
    case 'h':
      return 'c';
    case 'cpp':
    case 'cc':
    case 'cxx':
    case 'c++':
    case 'hpp':
    case 'hxx':
    case 'h++':
    case 'hh':
      return 'cpp';
    case 'cs':
      return 'csharp';
    case 'go':
      return 'go';
    case 'rs':
      return 'rust';
    case 'rb':
    case 'rbw':
    case 'rake':
      return 'ruby';
    case 'php':
    case 'phtml':
    case 'php3':
    case 'php4':
    case 'php5':
      return 'php';
    case 'swift':
      return 'swift';
    case 'kt':
    case 'kts':
      return 'kotlin';
    case 'scala':
    case 'sc':
      return 'scala';
    case 'clj':
    case 'cljs':
    case 'cljc':
      return 'clojure';
    case 'hs':
    case 'lhs':
      return 'haskell';
    case 'elm':
      return 'elm';
    case 'ex':
    case 'exs':
      return 'elixir';
    case 'erl':
    case 'hrl':
      return 'erlang';
    case 'ml':
    case 'mli':
      return 'ocaml';
    case 'fs':
    case 'fsi':
    case 'fsx':
      return 'fsharp';
    case 'vb':
    case 'vbs':
      return 'vbscript';
    case 'vbnet':
      return 'vbnet';
    
    // Scripting languages
    case 'sh':
    case 'bash':
    case 'zsh':
      return 'bash';
    case 'ps1':
    case 'psm1':
    case 'psd1':
      return 'powershell';
    case 'pl':
    case 'pm':
    case 'pod':
      return 'perl';
    case 'lua':
      return 'lua';
    case 'r':
    case 'rdata':
    case 'rds':
      return 'r';
    case 'vim':
    case 'vimrc':
      return 'vim';
    case 'tcl':
      return 'tcl';
    case 'awk':
      return 'awk';
    case 'sed':
      return 'bash'; // sed scripts are shell-like
    
    // Data formats
    case 'json':
    case 'jsonc':
    case 'json5':
      return 'json';
    case 'yaml':
    case 'yml':
      return 'yaml';
    case 'toml':
      return 'toml';
    case 'ini':
    case 'cfg':
    case 'conf':
      return 'ini';
    case 'properties':
      return 'properties';
    
    // Markup
    case 'md':
    case 'markdown':
    case 'mdown':
    case 'mkd':
      return 'markdown';
    case 'tex':
    case 'latex':
      return 'tex';
    case 'rst':
      return 'plaintext'; // reStructuredText not in highlight
    
    // Database
    case 'sql':
      return 'sql';
    case 'pgsql':
      return 'pgsql';
    
    // Build/config files
    case 'cmake':
      return 'cmake';
    case 'makefile':
    case 'mk':
      return 'makefile';
    case 'gradle':
      return 'gradle';
    case 'maven':
      return 'xml';
    case 'dockerfile':
      return 'dockerfile';
    
    // Other
    case 'git':
    case 'gitignore':
    case 'gitattributes':
    case 'gitmodules':
      return 'git';
    case 'diff':
    case 'patch':
      return 'diff';
    case 'log':
      return 'accesslog';
    case 'nginx':
      return 'nginx';
    case 'apache':
    case 'apacheconf':
      return 'apache';
    
    default:
      return null;
  }
}
