import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/shared/services/explorer_state.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_chrome_state.dart';

class _FakeExplorerController extends ChangeNotifier
    implements FileExplorerController {
  _FakeExplorerController() {
    state.searchActive = false;
  }

  @override
  String currentPath = '/tmp';

  bool osDragActive = false;
  bool selfDragTarget = false;

  @override
  final ExplorerState state = ExplorerState();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get isOsDragActive => osDragActive;

  @override
  bool isSelfDragTarget(String targetDirectory) => selfDragTarget;

  @override
  ExplorerContext get explorerContext =>
      ExplorerContext.server(const SshHost(name: 'host', hostname: '127.0.0.1', port: 22, available: true));

  @override
  Future<void> setSearchActive(bool value) async {
    state.searchActive = value;
  }
}

void main() {
  test('drop hover updates and clears', () {
    final controller = _FakeExplorerController();
    final chrome = FileExplorerTabChromeState(
      controller: controller,
      showSettings: () => false,
      onToggleSettings: () {},
      onUploadFiles: (_) {},
      onUploadFolder: (_) {},
      onOpenTrash: () {},
      onOpenTerminalTab: null,
    );

    expect(chrome.handleDropEntered(), true);
    expect(chrome.dropHover, true);
    expect(chrome.handleDropUpdated(), false);
    expect(chrome.handleDropExited(), true);
    expect(chrome.dropHover, false);
  });

  test('drop hover ignores self-drag targets', () {
    final controller = _FakeExplorerController()..selfDragTarget = true;
    final chrome = FileExplorerTabChromeState(
      controller: controller,
      showSettings: () => false,
      onToggleSettings: () {},
      onUploadFiles: (_) {},
      onUploadFolder: (_) {},
      onOpenTrash: () {},
      onOpenTerminalTab: null,
    );

    expect(chrome.handleDropEntered(), false);
    expect(chrome.dropHover, false);
  });

  test('tab options include terminal action when available', () {
    final controller = _FakeExplorerController();
    final notifier = CompositeTabOptionsController();
    final chrome = FileExplorerTabChromeState(
      controller: controller,
      showSettings: () => true,
      onToggleSettings: () {},
      onUploadFiles: (_) {},
      onUploadFolder: (_) {},
      onOpenTrash: () {},
      onOpenTerminalTab: (_) {},
    );

    chrome.updateTabOptions(notifier);

    expect(notifier.value.map((option) => option.label), containsAll(<String>[
      'Upload files…',
      'Show search',
      'Upload folder…',
      'Open trash',
      'Open terminal here',
      'Hide settings',
    ]));
  });
}
