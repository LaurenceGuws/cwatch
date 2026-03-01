import 'dart:convert';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

import 'zide_editor_ffi_bridge.dart';
import 'zide_ffi_backend_config.dart';
import 'zide_ffi_exception.dart';
import 'zide_terminal_ffi_bridge.dart';

class ZideFfiSmokeService {
  ZideFfiSmokeService({required this.settingsProvider});

  final AppSettings Function() settingsProvider;

  Future<String> runSmoke() async {
    final settings = _requireEnabledSettings();

    final log = <String>[];
    log.add('zide ffi smoke start');

    final terminalBridge = ZideTerminalFfiBridge.open(settings: settings);
    final terminalSummary = _runTerminalSmoke(terminalBridge);
    log.addAll(terminalSummary);

    final editorBridge = ZideEditorFfiBridge.open(settings: settings);
    final editorSummary = _runEditorSmoke(editorBridge);
    log.addAll(editorSummary);

    log.add('zide ffi smoke complete');
    final report = log.join('\n');
    AppLogger().info(report, tag: 'ZideFFI');
    return report;
  }

  Future<String> runTerminalSmokeOnly() async {
    final settings = _requireEnabledSettings();
    final bridge = ZideTerminalFfiBridge.open(settings: settings);
    final lines = <String>[
      'zide terminal-only smoke start',
      ..._runTerminalSmoke(bridge),
      'zide terminal-only smoke complete',
    ];
    final report = lines.join('\n');
    AppLogger().info(report, tag: 'ZideFFI');
    return report;
  }

  Future<String> runEditorSmokeOnly() async {
    final settings = _requireEnabledSettings();
    final bridge = ZideEditorFfiBridge.open(settings: settings);
    final lines = <String>[
      'zide editor-only smoke start',
      ..._runEditorSmoke(bridge),
      'zide editor-only smoke complete',
    ];
    final report = lines.join('\n');
    AppLogger().info(report, tag: 'ZideFFI');
    return report;
  }

  Future<String> runRegressionPack({bool quiet = false}) async {
    final startedAt = DateTime.now();
    final results = <_RegressionCaseResult>[];

    Future<void> runCase(String name, Future<void> Function() action) async {
      final caseStart = DateTime.now();
      try {
        await action();
        results.add(
          _RegressionCaseResult(
            name: name,
            passed: true,
            durationMs: DateTime.now().difference(caseStart).inMilliseconds,
            detail: 'ok',
          ),
        );
      } catch (error) {
        results.add(
          _RegressionCaseResult(
            name: name,
            passed: false,
            durationMs: DateTime.now().difference(caseStart).inMilliseconds,
            detail: '$error',
          ),
        );
      }
    }

    await runCase('terminal/full_smoke', () async {
      final report = await runTerminalSmokeOnly();
      if (!report.contains('terminal ffi smoke ok')) {
        throw const ZideFfiException('missing terminal smoke success marker');
      }
      if (!report.contains('terminal events ok')) {
        throw const ZideFfiException('terminal events marker missing');
      }
    });

    await runCase('editor/full_smoke', () async {
      final report = await runEditorSmokeOnly();
      if (!report.contains('editor ffi smoke ok')) {
        throw const ZideFfiException('missing editor smoke success marker');
      }
      if (!report.contains('line_count=')) {
        throw const ZideFfiException('editor line_count marker missing');
      }
    });

    await runCase('editor/script_ops', () async {
      final settings = _requireEnabledSettings();
      final bridge = ZideEditorFfiBridge.open(settings: settings);
      final handle = bridge.create();
      try {
        bridge.setText(handle, 'a b c\n');
        bridge.replaceRange(handle, start: 0, end: 1, text: 'A');
        bridge.insertText(handle, ' tail');
        bridge.searchSetQuery(handle, query: 'tail');
        final matches = bridge.searchMatchCount(handle);
        if (matches < 1) {
          throw const ZideFfiException('expected at least one search match');
        }
        final changedUndo = bridge.undo(handle);
        if (!changedUndo) {
          throw const ZideFfiException('expected undo change');
        }
        final changedRedo = bridge.redo(handle);
        if (!changedRedo) {
          throw const ZideFfiException('expected redo change');
        }
      } finally {
        bridge.destroy(handle);
      }
    });

    await runCase('editor/search_cycle', () async {
      final settings = _requireEnabledSettings();
      final bridge = ZideEditorFfiBridge.open(settings: settings);
      final handle = bridge.create();
      try {
        bridge.setText(handle, 'alpha beta alpha beta\n');
        bridge.searchSetQuery(handle, query: 'beta');
        final totalMatches = bridge.searchMatchCount(handle);
        if (totalMatches != 2) {
          throw ZideFfiException(
            'search_cycle expected 2 matches, got $totalMatches',
          );
        }
        if (!bridge.searchNext(handle)) {
          throw const ZideFfiException('search_cycle next did not activate');
        }
        final first = bridge.searchActiveIndex(handle);
        if (!first.hasActive ||
            first.index < 0 ||
            first.index >= totalMatches) {
          throw ZideFfiException(
            'search_cycle first active invalid: has=${first.hasActive} index=${first.index}',
          );
        }
        if (!bridge.searchNext(handle)) {
          throw const ZideFfiException(
            'search_cycle second next did not activate',
          );
        }
        final second = bridge.searchActiveIndex(handle);
        if (!second.hasActive || second.index == first.index) {
          throw ZideFfiException(
            'search_cycle expected different second active index, got ${second.index}',
          );
        }
        if (!bridge.searchPrev(handle)) {
          throw const ZideFfiException('search_cycle prev did not activate');
        }
        final third = bridge.searchActiveIndex(handle);
        if (!third.hasActive || third.index != first.index) {
          throw ZideFfiException(
            'search_cycle prev did not return to first index: ${third.index}',
          );
        }
      } finally {
        bridge.destroy(handle);
      }
    });

    await runCase('terminal/cursor_fixture', () async {
      final settings = _requireEnabledSettings();
      final bridge = ZideTerminalFfiBridge.open(settings: settings);
      final handle = bridge.create(
        rows: 6,
        cols: 20,
        scrollbackRows: 32,
        cursorShape: 0,
        cursorBlink: true,
      );
      try {
        bridge.resize(handle, cols: 20, rows: 6, cellWidth: 8, cellHeight: 16);
        bridge.poll(handle);
        bridge.feedOutput(
          handle,
          utf8.encode(
            'a\r\n'
            'b\r\n'
            'c\r\n'
            '\x1b[2A'
            '\x1b[15C',
          ),
        );

        final snapshot = bridge.acquireSnapshot(handle);
        try {
          final data = bridge.readSnapshot(snapshot);
          if (data.cursorRow != 1 || data.cursorCol != 15) {
            throw ZideFfiException(
              'cursor fixture mismatch expected=1,15 actual=${data.cursorRow},${data.cursorCol}',
            );
          }
        } finally {
          bridge.releaseSnapshot(snapshot);
        }
      } finally {
        bridge.destroy(handle);
      }
    });

    await runCase('terminal/lifecycle_loop', () async {
      final settings = _requireEnabledSettings();
      final bridge = ZideTerminalFfiBridge.open(settings: settings);
      final iterations = quiet ? 3 : 10;
      for (var i = 0; i < iterations; i++) {
        final handle = bridge.create(
          rows: 6,
          cols: 20,
          scrollbackRows: 32,
          cursorShape: 0,
          cursorBlink: true,
        );
        try {
          bridge.resize(
            handle,
            cols: 20,
            rows: 6,
            cellWidth: 8,
            cellHeight: 16,
          );
          bridge.poll(handle);
          final snapshot = bridge.acquireSnapshot(handle);
          try {
            final data = bridge.readSnapshot(snapshot);
            if (data.rows != 6 || data.cols != 20) {
              throw ZideFfiException(
                'loop snapshot dimensions mismatch: ${data.rows}x${data.cols}',
              );
            }
          } finally {
            bridge.releaseSnapshot(snapshot);
          }
        } finally {
          bridge.destroy(handle);
        }
      }
    });

    await runCase('terminal/snapshot_generation', () async {
      final settings = _requireEnabledSettings();
      final bridge = ZideTerminalFfiBridge.open(settings: settings);
      final handle = bridge.create(
        rows: 6,
        cols: 20,
        scrollbackRows: 32,
        cursorShape: 0,
        cursorBlink: true,
      );
      try {
        bridge.resize(handle, cols: 20, rows: 6, cellWidth: 8, cellHeight: 16);
        bridge.poll(handle);

        final beforeSnapshot = bridge.acquireSnapshot(handle);
        late final int beforeGeneration;
        try {
          beforeGeneration = bridge.readSnapshot(beforeSnapshot).generation;
        } finally {
          bridge.releaseSnapshot(beforeSnapshot);
        }

        bridge.feedOutput(handle, utf8.encode('gen-check\r\n'));
        bridge.poll(handle);

        final afterSnapshot = bridge.acquireSnapshot(handle);
        try {
          final afterData = bridge.readSnapshot(afterSnapshot);
          final row0 = bridge.readFirstRow(afterSnapshot);
          if (afterData.generation < beforeGeneration) {
            throw ZideFfiException(
              'snapshot generation regressed: before=$beforeGeneration after=${afterData.generation}',
            );
          }
          if (!row0.contains('gen-check')) {
            throw ZideFfiException(
              'snapshot generation fixture missing marker in row0: $row0',
            );
          }
        } finally {
          bridge.releaseSnapshot(afterSnapshot);
        }
      } finally {
        bridge.destroy(handle);
      }
    });

    await runCase('terminal/send_bytes_pty', () async {
      final settings = _requireEnabledSettings();
      final bridge = ZideTerminalFfiBridge.open(settings: settings);
      final handle = bridge.create(
        rows: 8,
        cols: 40,
        scrollbackRows: 64,
        cursorShape: 0,
        cursorBlink: true,
      );
      try {
        bridge.resize(handle, cols: 40, rows: 8, cellWidth: 8, cellHeight: 16);
        bridge.start(handle, shell: '/bin/sh');
        bridge.sendBytes(handle, utf8.encode("printf 'SBOK\\n'; exit 7\n"));

        var sawMarker = false;
        var sawExit = false;
        for (var i = 0; i < 50; i++) {
          bridge.poll(handle);
          final snapshot = bridge.acquireSnapshot(handle);
          try {
            final text = bridge.snapshotToPlainText(snapshot);
            if (text.contains('SBOK')) {
              sawMarker = true;
            }
          } finally {
            bridge.releaseSnapshot(snapshot);
          }

          final exit = bridge.childExitStatus(handle);
          if (exit.hasStatus) {
            sawExit = true;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        if (!sawMarker) {
          throw const ZideFfiException(
            'send_bytes pty did not emit SBOK marker',
          );
        }
        if (!sawExit) {
          throw const ZideFfiException(
            'send_bytes pty did not report child exit',
          );
        }
      } finally {
        bridge.destroy(handle);
      }
    });

    await runCase('terminal/bad_library_path', () async {
      final settings = _requireEnabledSettings();
      try {
        ZideTerminalFfiBridge.open(
          settings: settings,
          overrideLibraryPath: '/tmp/cwatch-zide-missing-lib-do-not-create.so',
        );
      } catch (error) {
        final message = '$error';
        if (!message.contains('not found')) {
          throw ZideFfiException(
            'expected not-found library error, got: $message',
          );
        }
        return;
      }
      throw const ZideFfiException(
        'expected library open failure for invalid override path',
      );
    });

    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    final passed = results.where((result) => result.passed).length;
    final failed = results.length - passed;

    final lines = <String>[
      'zide regression pack',
      'quiet_mode=$quiet',
      'total_cases=${results.length} passed=$passed failed=$failed duration_ms=$elapsedMs',
      '',
      'case | status | ms | detail',
      '---- | ------ | -- | ------',
      ...results.map(
        (result) =>
            '${result.name} | ${result.passed ? 'PASS' : 'FAIL'} | '
            '${result.durationMs} | ${result.detail}',
      ),
    ];
    final report = lines.join('\n');
    AppLogger().info(report, tag: 'ZideFFI');
    return report;
  }

  Future<String> runSanityCheck({bool quiet = true}) async {
    final startedAt = DateTime.now();
    final sections = <String>[];

    Future<bool> runBlock(String name, Future<String> Function() action) async {
      try {
        final report = await action();
        sections.add('[$name] PASS');
        sections.add(report);
        sections.add('');
        return true;
      } catch (error) {
        sections.add('[$name] FAIL');
        sections.add('$error');
        sections.add('');
        return false;
      }
    }

    final smokeOk = await runBlock('smoke', runSmoke);
    final regressionOk = await runBlock(
      'regression',
      () => runRegressionPack(quiet: quiet),
    );

    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    final overall = smokeOk && regressionOk ? 'PASS' : 'FAIL';
    final summary = <String>[
      'zide migration sanity verdict=$overall duration_ms=$elapsedMs quiet_mode=$quiet',
      'smoke=${smokeOk ? 'PASS' : 'FAIL'} regression=${regressionOk ? 'PASS' : 'FAIL'}',
      '',
      ...sections,
    ].join('\n');

    AppLogger().info(summary, tag: 'ZideFFI');
    return summary;
  }

  AppSettings _requireEnabledSettings() {
    final settings = settingsProvider();
    final config = ZideFfiBackendConfig(settings: settings);
    if (!config.enabled) {
      throw const ZideFfiException(
        'Zide FFI backend is disabled. Enable it in Settings > General or set CWATCH_ZIDE_FFI_BACKEND=1.',
      );
    }
    return settings;
  }

  List<String> _runTerminalSmoke(ZideTerminalFfiBridge bridge) {
    final lines = <String>[];
    final handle = bridge.create(
      rows: 12,
      cols: 60,
      scrollbackRows: 256,
      cursorShape: 0,
      cursorBlink: true,
    );

    try {
      bridge.resize(handle, cols: 60, rows: 12, cellWidth: 8, cellHeight: 16);
      bridge.poll(handle);

      final vt = '\x1b]0;ffi-title\x07\x1b]52;c;ZmZpLWNsaXA=\x07';
      bridge.feedOutput(handle, vt.codeUnits);

      final snapshot = bridge.acquireSnapshot(handle);
      try {
        final data = bridge.readSnapshot(snapshot);
        final frame = bridge.snapshotToFrame(snapshot);
        final row0 = bridge.readFirstRow(snapshot);

        final titleGetter = bridge.currentTitle(handle);
        final cwdGetter = bridge.currentCwd(handle);

        if (data.rows != 12 || data.cols != 60) {
          throw ZideFfiException(
            'terminal snapshot dimensions mismatch: ${data.rows}x${data.cols}',
          );
        }
        if (data.cellCount != 12 * 60) {
          throw ZideFfiException(
            'terminal cell count mismatch: ${data.cellCount}',
          );
        }
        if (data.title != 'ffi-title') {
          throw ZideFfiException('terminal title mismatch: ${data.title}');
        }
        if (titleGetter != data.title || cwdGetter != data.cwd) {
          throw const ZideFfiException(
            'terminal title/cwd getter mismatch with snapshot',
          );
        }
        if (frame.rows != data.rows || frame.cols != data.cols) {
          throw const ZideFfiException(
            'terminal frame dimensions mismatch with snapshot',
          );
        }
        if (frame.cells.length != data.cellCount) {
          throw ZideFfiException(
            'terminal frame cell count mismatch: ${frame.cells.length}',
          );
        }
        if (frame.cursorRow < 0 ||
            frame.cursorRow >= data.rows ||
            frame.cursorCol < 0 ||
            frame.cursorCol >= data.cols) {
          throw ZideFfiException(
            'terminal cursor out of bounds: ${frame.cursorRow},${frame.cursorCol}',
          );
        }

        lines.add('terminal ffi smoke ok');
        lines.add(
          'terminal library=${bridge.libraryPath} '
          'snapshot_abi=${bridge.snapshotAbiVersion()} '
          'event_abi=${bridge.eventAbiVersion()}',
        );
        lines.add(
          'terminal size=${data.rows}x${data.cols} '
          'cells=${data.cellCount} alive=${bridge.isAlive(handle)}',
        );
        lines.add(
          'terminal title=${jsonEncode(data.title)} cwd=${jsonEncode(data.cwd)}',
        );
        lines.add('terminal row0=${jsonEncode(row0)}');
      } finally {
        bridge.releaseSnapshot(snapshot);
      }

      final events = bridge.drainEvents(handle);
      final hasTitle = events.any(
        (event) => event.kind == 1 && utf8.decode(event.payload) == 'ffi-title',
      );
      final hasClipboard = events.any(
        (event) => event.kind == 3 && utf8.decode(event.payload) == 'ffi-clip',
      );

      if (!hasTitle) {
        throw const ZideFfiException('terminal missing title_changed event');
      }
      if (!hasClipboard) {
        throw const ZideFfiException('terminal missing clipboard_write event');
      }
      lines.add('terminal events ok count=${events.length}');

      // Second drain should typically be empty for this smoke path; if not,
      // the backend may still be producing events unexpectedly.
      final secondDrain = bridge.drainEvents(handle);
      if (secondDrain.isNotEmpty) {
        throw ZideFfiException(
          'terminal second drain expected empty but got ${secondDrain.length} events',
        );
      }
      lines.add('terminal events second_drain_ok count=0');
      return lines;
    } finally {
      bridge.destroy(handle);
    }
  }

  List<String> _runEditorSmoke(ZideEditorFfiBridge bridge) {
    final lines = <String>[];
    final handle = bridge.create();
    try {
      bridge.setText(handle, 'foo bar foo\nline two\n');
      bridge.setCursorOffset(handle, 4);
      bridge.insertText(handle, 'ZZ ');
      bridge.replaceRange(handle, start: 0, end: 3, text: 'hey');
      bridge.deleteRange(handle, start: 3, end: 4);

      bridge.beginUndoGroup(handle);
      bridge.replaceRange(handle, start: 0, end: 3, text: 'YO');
      bridge.replaceRange(handle, start: 5, end: 7, text: 'XX');
      bridge.endUndoGroup(handle);

      if (!bridge.undo(handle)) {
        throw const ZideFfiException('editor undo did not change document');
      }
      if (!bridge.redo(handle)) {
        throw const ZideFfiException('editor redo did not change document');
      }

      bridge.setCarets(handle, primaryOffset: 1, auxiliaryOffsets: [2, 8]);
      final primary = bridge.primaryCaretOffset(handle);
      final auxCount = bridge.auxCaretCount(handle);
      if (primary != 1 || auxCount != 2) {
        throw ZideFfiException(
          'editor caret mismatch primary=$primary aux_count=$auxCount',
        );
      }
      if (bridge.auxCaretGet(handle, 0) != 2 ||
          bridge.auxCaretGet(handle, 1) != 8) {
        throw const ZideFfiException('editor auxiliary caret offsets mismatch');
      }

      bridge.searchSetQuery(handle, query: 'foo', useRegex: false);
      final matchCount = bridge.searchMatchCount(handle);
      if (matchCount < 1) {
        throw const ZideFfiException('editor search_match_count expected >= 1');
      }
      final firstMatch = bridge.searchMatchGet(handle, 0);
      if (firstMatch.start < 0 || firstMatch.end <= firstMatch.start) {
        throw ZideFfiException(
          'editor invalid first match range: ${firstMatch.start}-${firstMatch.end}',
        );
      }
      final activated = bridge.searchNext(handle);
      if (!activated) {
        throw const ZideFfiException('editor search_next did not activate');
      }
      final active = bridge.searchActiveIndex(handle);
      if (!active.hasActive || active.index < 0 || active.index >= matchCount) {
        throw ZideFfiException(
          'editor active match mismatch: has_active=${active.hasActive} index=${active.index}',
        );
      }

      final replaced = bridge.searchReplaceActive(handle, replacement: 'qq');
      if (!replaced) {
        throw const ZideFfiException(
          'editor search_replace_active did not replace',
        );
      }
      final replacedAll = bridge.searchReplaceAll(handle, replacement: 'R');
      final text = bridge.textAlloc(handle);
      final textSecondRead = bridge.textAlloc(handle);
      if (textSecondRead != text) {
        throw const ZideFfiException(
          'editor text_alloc returned unstable content',
        );
      }
      final lineCount = bridge.lineCount(handle);
      final totalLen = bridge.totalLength(handle);
      if (lineCount < 1 || totalLen != text.length) {
        throw ZideFfiException(
          'editor line/length mismatch line_count=$lineCount total_len=$totalLen text_len=${text.length}',
        );
      }

      lines.add('editor ffi smoke ok');
      lines.add(
        'editor library=${bridge.libraryPath} '
        'primary=$primary aux_count=$auxCount matches=$matchCount '
        'replaced_all=$replacedAll',
      );
      lines.add('editor line_count=$lineCount total_len=$totalLen');
      lines.add('editor text=${jsonEncode(text)}');
      return lines;
    } finally {
      bridge.destroy(handle);
    }
  }
}

class _RegressionCaseResult {
  const _RegressionCaseResult({
    required this.name,
    required this.passed,
    required this.durationMs,
    required this.detail,
  });

  final String name;
  final bool passed;
  final int durationMs;
  final String detail;
}
