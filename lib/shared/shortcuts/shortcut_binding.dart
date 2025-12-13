import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ShortcutBinding {
  const ShortcutBinding({
    required this.key,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  final LogicalKeyboardKey key;
  final bool control;
  final bool alt;
  final bool shift;
  final bool meta;

  static ShortcutBinding? tryParse(String? input) {
    final value = input?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;

    final parts = value
        .split('+')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);

    var control = false;
    var alt = false;
    var shift = false;
    var meta = false;
    LogicalKeyboardKey? key;

    for (final part in parts) {
      switch (part) {
        case 'ctrl':
        case 'control':
          control = true;
          continue;
        case 'alt':
        case 'option':
          alt = true;
          continue;
        case 'shift':
          shift = true;
          continue;
        case 'cmd':
        case 'command':
        case 'meta':
        case 'super':
          meta = true;
          continue;
        default:
          key = _parseKeyToken(part);
      }
    }

    if (key == null) {
      return null;
    }

    return ShortcutBinding(
      key: key,
      control: control,
      alt: alt,
      shift: shift,
      meta: meta,
    );
  }

  static ShortcutBinding? fromKeyEvent(KeyEvent event) {
    final key = _normalizeKey(event.logicalKey);
    if (key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.meta) {
      return null;
    }
    final hardware = HardwareKeyboard.instance;
    return ShortcutBinding(
      key: key,
      control: hardware.isControlPressed,
      alt: hardware.isAltPressed,
      shift: hardware.isShiftPressed,
      meta: hardware.isMetaPressed,
    );
  }

  ShortcutActivator toActivator() {
    return SingleActivator(
      key,
      control: control,
      alt: alt,
      shift: shift,
      meta: meta,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShortcutBinding &&
        other.key == key &&
        other.control == control &&
        other.alt == alt &&
        other.shift == shift &&
        other.meta == meta;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      control.hashCode ^
      alt.hashCode ^
      shift.hashCode ^
      meta.hashCode;

  String toConfigString() {
    final parts = <String>[];
    if (control) parts.add('ctrl');
    if (shift) parts.add('shift');
    if (alt) parts.add('alt');
    if (meta) parts.add('meta');
    parts.add(_formatKey(key, shifted: shift));
    return parts.join('+');
  }

  static LogicalKeyboardKey? _parseKeyToken(String token) {
    if (token.length == 1) {
      final rune = token.runes.first;
      if (rune >= 0x61 && rune <= 0x7a) {
        return _letterKey(rune - 0x61);
      }
      if (rune >= 0x30 && rune <= 0x39) {
        return _digitKey(rune - 0x30);
      }
      if (token == '=' || token == '+') return LogicalKeyboardKey.equal;
      if (token == '-' || token == '_') return LogicalKeyboardKey.minus;
    }

    switch (token) {
      case 'plus':
      case 'add':
        return LogicalKeyboardKey.equal;
      case 'minus':
      case 'subtract':
      case 'underscore':
      case 'dash':
      case 'hyphen':
        return LogicalKeyboardKey.minus;
      case 'enter':
      case 'return':
        return LogicalKeyboardKey.enter;
      case 'space':
        return LogicalKeyboardKey.space;
      case 'tab':
        return LogicalKeyboardKey.tab;
      case 'escape':
      case 'esc':
        return LogicalKeyboardKey.escape;
      case 'backspace':
        return LogicalKeyboardKey.backspace;
      case 'delete':
      case 'del':
        return LogicalKeyboardKey.delete;
      case 'home':
        return LogicalKeyboardKey.home;
      case 'end':
        return LogicalKeyboardKey.end;
      case 'pageup':
      case 'page-up':
        return LogicalKeyboardKey.pageUp;
      case 'pagedown':
      case 'page-down':
        return LogicalKeyboardKey.pageDown;
      case 'arrowup':
      case 'up':
        return LogicalKeyboardKey.arrowUp;
      case 'arrowdown':
      case 'down':
        return LogicalKeyboardKey.arrowDown;
      case 'arrowleft':
      case 'left':
        return LogicalKeyboardKey.arrowLeft;
      case 'arrowright':
      case 'right':
        return LogicalKeyboardKey.arrowRight;
      default:
        if (token.startsWith('f')) {
          final maybeNumber = int.tryParse(token.substring(1));
          if (maybeNumber != null && maybeNumber >= 1 && maybeNumber <= 24) {
            return LogicalKeyboardKey(
              LogicalKeyboardKey.f1.keyId + (maybeNumber - 1) * 0x000200000,
            );
          }
        }
    }
    return null;
  }

  static LogicalKeyboardKey _letterKey(int index) {
    switch (index) {
      case 0:
        return LogicalKeyboardKey.keyA;
      case 1:
        return LogicalKeyboardKey.keyB;
      case 2:
        return LogicalKeyboardKey.keyC;
      case 3:
        return LogicalKeyboardKey.keyD;
      case 4:
        return LogicalKeyboardKey.keyE;
      case 5:
        return LogicalKeyboardKey.keyF;
      case 6:
        return LogicalKeyboardKey.keyG;
      case 7:
        return LogicalKeyboardKey.keyH;
      case 8:
        return LogicalKeyboardKey.keyI;
      case 9:
        return LogicalKeyboardKey.keyJ;
      case 10:
        return LogicalKeyboardKey.keyK;
      case 11:
        return LogicalKeyboardKey.keyL;
      case 12:
        return LogicalKeyboardKey.keyM;
      case 13:
        return LogicalKeyboardKey.keyN;
      case 14:
        return LogicalKeyboardKey.keyO;
      case 15:
        return LogicalKeyboardKey.keyP;
      case 16:
        return LogicalKeyboardKey.keyQ;
      case 17:
        return LogicalKeyboardKey.keyR;
      case 18:
        return LogicalKeyboardKey.keyS;
      case 19:
        return LogicalKeyboardKey.keyT;
      case 20:
        return LogicalKeyboardKey.keyU;
      case 21:
        return LogicalKeyboardKey.keyV;
      case 22:
        return LogicalKeyboardKey.keyW;
      case 23:
        return LogicalKeyboardKey.keyX;
      case 24:
        return LogicalKeyboardKey.keyY;
      case 25:
        return LogicalKeyboardKey.keyZ;
      default:
        return LogicalKeyboardKey.keyA;
    }
  }

  static LogicalKeyboardKey _digitKey(int value) {
    switch (value) {
      case 0:
        return LogicalKeyboardKey.digit0;
      case 1:
        return LogicalKeyboardKey.digit1;
      case 2:
        return LogicalKeyboardKey.digit2;
      case 3:
        return LogicalKeyboardKey.digit3;
      case 4:
        return LogicalKeyboardKey.digit4;
      case 5:
        return LogicalKeyboardKey.digit5;
      case 6:
        return LogicalKeyboardKey.digit6;
      case 7:
        return LogicalKeyboardKey.digit7;
      case 8:
        return LogicalKeyboardKey.digit8;
      case 9:
        return LogicalKeyboardKey.digit9;
      default:
        return LogicalKeyboardKey.digit0;
    }
  }

  static String _formatKey(LogicalKeyboardKey key, {bool shifted = false}) {
    if (key == LogicalKeyboardKey.equal) {
      return shifted ? '+' : '=';
    }
    if (key == LogicalKeyboardKey.minus) {
      return shifted ? '_' : '-';
    }
    final label = key.keyLabel;
    if (label.isNotEmpty && label.length == 1) {
      return label.toLowerCase();
    }

    if (key == LogicalKeyboardKey.arrowUp) return 'arrowup';
    if (key == LogicalKeyboardKey.arrowDown) return 'arrowdown';
    if (key == LogicalKeyboardKey.arrowLeft) return 'arrowleft';
    if (key == LogicalKeyboardKey.arrowRight) return 'arrowright';
    if (key == LogicalKeyboardKey.pageUp) return 'pageup';
    if (key == LogicalKeyboardKey.pageDown) return 'pagedown';
    if (key == LogicalKeyboardKey.home) return 'home';
    if (key == LogicalKeyboardKey.end) return 'end';
    if (key == LogicalKeyboardKey.enter) return 'enter';
    if (key == LogicalKeyboardKey.escape) return 'escape';
    if (key == LogicalKeyboardKey.space) return 'space';
    if (key == LogicalKeyboardKey.tab) return 'tab';

    final number = _functionKeyNumber(key);
    if (number != null) return 'f$number';

    return key.debugName?.toLowerCase() ?? 'key';
  }

  static int? _functionKeyNumber(LogicalKeyboardKey key) {
    final f1Id = LogicalKeyboardKey.f1.keyId;
    final f24Id = LogicalKeyboardKey.f24.keyId;
    if (key.keyId < f1Id || key.keyId > f24Id) {
      return null;
    }
    return ((key.keyId - f1Id) ~/ 0x000200000) + 1;
  }

  static LogicalKeyboardKey _normalizeKey(LogicalKeyboardKey key) {
    // Normalize shifted punctuation keys to their unshifted logical keys
    if (key.keyId == 0x0000002b) {
      // '+' keyId
      return LogicalKeyboardKey.equal;
    }
    if (key.keyId == 0x0000005f) {
      // '_' keyId
      return LogicalKeyboardKey.minus;
    }
    return key;
  }
}
