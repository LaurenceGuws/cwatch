import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/all.dart' as all_langs;

Mode? languageForKey(String? languageId) {
  if (languageId == null) return null;

  String? lookupKey = languageId;
  switch (languageId) {
    case 'js':
      lookupKey = 'javascript';
      break;
    case 'ts':
      lookupKey = 'typescript';
      break;
    case 'py':
      lookupKey = 'python';
      break;
    case 'sh':
      lookupKey = 'bash';
      break;
    case 'c':
    case 'cxx':
    case 'cc':
      lookupKey = 'cpp';
      break;
    case 'csharp':
      lookupKey = 'cs';
      break;
    case 'rs':
      lookupKey = 'rust';
      break;
    case 'rb':
      lookupKey = 'ruby';
      break;
    case 'kt':
      lookupKey = 'kotlin';
      break;
    case 'yml':
      lookupKey = 'yaml';
      break;
    case 'html':
      lookupKey = 'xml';
      break;
    case 'md':
      lookupKey = 'markdown';
      break;
    case 'pl':
      lookupKey = 'perl';
      break;
    case 'docker':
      lookupKey = 'dockerfile';
      break;
    case 'git':
    case 'toml':
      return null;
    default:
      lookupKey = languageId;
  }

  return all_langs.allLanguages[lookupKey];
}

String? languageFromPath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return null;
  final baseName = trimmed.split('/').last.toLowerCase();
  switch (baseName) {
    case '.bashrc':
    case '.bash_profile':
    case '.profile':
    case '.zshrc':
    case '.zprofile':
      return 'bash';
    case 'dockerfile':
    case 'containerfile':
      return 'dockerfile';
    default:
      break;
  }
  final dotIndex = trimmed.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == trimmed.length - 1) return null;
  final ext = trimmed.substring(dotIndex + 1).toLowerCase();
  switch (ext) {
    case 'dart':
      return 'dart';
    case 'js':
    case 'jsx':
      return 'javascript';
    case 'ts':
    case 'tsx':
      return 'typescript';
    case 'json':
      return 'json';
    case 'yml':
    case 'yaml':
      return 'yaml';
    case 'md':
    case 'markdown':
      return 'markdown';
    case 'sh':
    case 'bash':
      return 'bash';
    case 'go':
      return 'go';
    case 'rs':
      return 'rust';
    case 'py':
      return 'python';
    case 'rb':
      return 'ruby';
    case 'php':
      return 'php';
    case 'java':
      return 'java';
    case 'kt':
    case 'kts':
      return 'kotlin';
    case 'swift':
      return 'swift';
    case 'c':
      return 'c';
    case 'cpp':
    case 'cc':
    case 'cxx':
    case 'hpp':
    case 'hh':
    case 'hxx':
      return 'cpp';
    case 'cs':
      return 'csharp';
    case 'html':
    case 'htm':
      return 'html';
    case 'css':
      return 'css';
    case 'xml':
      return 'xml';
    case 'toml':
      return 'toml';
    case 'dockerfile':
      return 'dockerfile';
    default:
      return null;
  }
}

List<String> availableLanguageKeys() {
  final keys = all_langs.allLanguages.keys.toList();
  keys.sort();
  return keys;
}
