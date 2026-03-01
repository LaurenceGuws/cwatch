#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

DEFAULT_DEVICE="${CWATCH_DEVICE:-linux}"
DEFAULT_TERMINAL_LIB="${CWATCH_ZIDE_TERMINAL_LIB:-/home/home/personal/zide/zig-out/lib/libzide-terminal-ffi.so}"
DEFAULT_EDITOR_LIB="${CWATCH_ZIDE_EDITOR_LIB:-/home/home/personal/zide/releases/beta-0.0.1/linux-x86_64/editor-ffi/libzide-editor-ffi.so}"

print_help() {
  cat <<'EOF'
Usage:
  ./rerun.sh <mode>

Modes:
  app                 Run flutter app on Linux with current environment.
  native              Run app with Zide native terminal+editor FFI libs.
  ui-smoke            Run app with focused migration UI logs.
  scroll-debug        Run app with focused terminal scroll logs.
  input-debug         Run app with terminal input/scroll/pty logs.
  analyze             Run flutter analyze.
  test-scrollback     Run targeted terminal scrollback controller test.
  test-editor-caret   Run targeted editor caret layout test.
  test-editor-nav     Run targeted editor text navigation test.
  migration-regression
                      Run migration pre-push checks (analyze + targeted tests).
  check               Run analyze + targeted test.
  help                Show this help.

Notes:
  - Override device with CWATCH_DEVICE (default: linux)
  - Override libs with CWATCH_ZIDE_TERMINAL_LIB / CWATCH_ZIDE_EDITOR_LIB
EOF
}

require_file() {
  local path="$1"
  local label="$2"
  if [[ ! -f "$path" ]]; then
    echo "missing $label: $path" >&2
    exit 1
  fi
}

mode="${1:-help}"

case "$mode" in
  app)
    flutter run -d "$DEFAULT_DEVICE"
    ;;
  native)
    require_file "$DEFAULT_TERMINAL_LIB" "terminal ffi lib"
    require_file "$DEFAULT_EDITOR_LIB" "editor ffi lib"
    CWATCH_ZIDE_TERMINAL_LIB="$DEFAULT_TERMINAL_LIB" \
    CWATCH_ZIDE_EDITOR_LIB="$DEFAULT_EDITOR_LIB" \
    flutter run -d "$DEFAULT_DEVICE"
    ;;
  ui-smoke)
    require_file "$DEFAULT_TERMINAL_LIB" "terminal ffi lib"
    require_file "$DEFAULT_EDITOR_LIB" "editor ffi lib"
    CWATCH_ZIDE_TERMINAL_LIB="$DEFAULT_TERMINAL_LIB" \
    CWATCH_ZIDE_EDITOR_LIB="$DEFAULT_EDITOR_LIB" \
    CWATCH_ZIDE_LOG_CONSOLE="${CWATCH_ZIDE_LOG_CONSOLE:-terminal.scroll,terminal.input}" \
    CWATCH_ZIDE_LOG_FILE="${CWATCH_ZIDE_LOG_FILE:-none}" \
    flutter run -d "$DEFAULT_DEVICE" 2>&1 | rg "ZideMigrationTerminal|keyboard:|mode=|\\[terminal\\.scroll\\]|\\[terminal\\.input\\]"
    ;;
  scroll-debug)
    require_file "$DEFAULT_TERMINAL_LIB" "terminal ffi lib"
    require_file "$DEFAULT_EDITOR_LIB" "editor ffi lib"
    CWATCH_ZIDE_TERMINAL_LIB="$DEFAULT_TERMINAL_LIB" \
    CWATCH_ZIDE_EDITOR_LIB="$DEFAULT_EDITOR_LIB" \
    CWATCH_ZIDE_LOG_CONSOLE="${CWATCH_ZIDE_LOG_CONSOLE:-terminal.scroll}" \
    CWATCH_ZIDE_LOG_FILE="${CWATCH_ZIDE_LOG_FILE:-none}" \
    flutter run -d "$DEFAULT_DEVICE" 2>&1 | rg "ZideMigrationTerminal|mode=|\\[terminal\\.scroll\\]"
    ;;
  input-debug)
    require_file "$DEFAULT_TERMINAL_LIB" "terminal ffi lib"
    require_file "$DEFAULT_EDITOR_LIB" "editor ffi lib"
    CWATCH_ZIDE_TERMINAL_LIB="$DEFAULT_TERMINAL_LIB" \
    CWATCH_ZIDE_EDITOR_LIB="$DEFAULT_EDITOR_LIB" \
    CWATCH_ZIDE_LOG_CONSOLE="${CWATCH_ZIDE_LOG_CONSOLE:-terminal.input,terminal.scroll,terminal.pty}" \
    CWATCH_ZIDE_LOG_FILE="${CWATCH_ZIDE_LOG_FILE:-none}" \
    flutter run -d "$DEFAULT_DEVICE" 2>&1 | rg "ZideMigrationTerminal|\\[terminal\\.input\\]|\\[terminal\\.scroll\\]|\\[terminal\\.pty\\]|mode="
    ;;
  analyze)
    flutter analyze
    ;;
  test-scrollback)
    flutter test test/view/features/migration/widgets/support/terminal_scrollback_controller_test.dart
    ;;
  test-editor-caret)
    flutter test test/view/features/migration/widgets/support/editor_caret_layout_test.dart
    ;;
  test-editor-nav)
    flutter test test/view/features/migration/widgets/support/editor_text_navigation_test.dart
    ;;
  migration-regression|regression)
    require_file "$DEFAULT_TERMINAL_LIB" "terminal ffi lib"
    require_file "$DEFAULT_EDITOR_LIB" "editor ffi lib"
    flutter analyze
    flutter test test/view/features/migration/widgets/support/terminal_scrollback_controller_test.dart
    flutter test test/view/features/migration/widgets/support/editor_caret_layout_test.dart
    flutter test test/view/features/migration/widgets/support/editor_text_navigation_test.dart
    cat <<EOF

migration regression checks passed.
manual ui run:
  CWATCH_ZIDE_TERMINAL_LIB="$DEFAULT_TERMINAL_LIB" \\
  CWATCH_ZIDE_EDITOR_LIB="$DEFAULT_EDITOR_LIB" \\
  flutter run -d "$DEFAULT_DEVICE"
EOF
    ;;
  check)
    flutter analyze
    flutter test test/view/features/migration/widgets/support/terminal_scrollback_controller_test.dart
    flutter test test/view/features/migration/widgets/support/editor_caret_layout_test.dart
    flutter test test/view/features/migration/widgets/support/editor_text_navigation_test.dart
    ;;
  help|-h|--help)
    print_help
    ;;
  *)
    echo "unknown mode: $mode" >&2
    print_help
    exit 1
    ;;
esac
