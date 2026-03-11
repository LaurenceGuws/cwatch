import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/shared/services/explorer_selection_state.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/selection_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ExplorerSelectionState state;
  late SelectionController controller;
  late List<RemoteFileEntry> entries;

  setUp(() {
    state = ExplorerSelectionState(
      currentPath: '/',
      joinPath: (base, name) => base == '/' ? '/$name' : '$base/$name',
    );
    controller = SelectionController(state: state);
    entries = [
      RemoteFileEntry(
        name: 'alpha.txt',
        isDirectory: false,
        sizeBytes: 10,
        modified: DateTime(2025),
      ),
      RemoteFileEntry(
        name: 'beta.txt',
        isDirectory: false,
        sizeBytes: 20,
        modified: DateTime(2025),
      ),
    ];
  });

  test('secondary click selects clicked entry when it is not selected', () {
    var builds = 0;
    controller.handleEntryPointerDown(
      PointerDownEvent(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      ),
      entries,
      1,
      '/beta.txt',
      () {},
      () => builds++,
    );

    expect(state.selectedPaths, {'/beta.txt'});
    expect(builds, 1);
  });

  test('secondary click preserves existing row selection', () {
    state.selectedPaths.add('/alpha.txt');
    var builds = 0;

    controller.handleEntryPointerDown(
      PointerDownEvent(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      ),
      entries,
      0,
      '/alpha.txt',
      () {},
      () => builds++,
    );

    expect(state.selectedPaths, {'/alpha.txt'});
    expect(builds, 0);
  });

  test('escape clears explorer selection', () {
    state.selectedPaths.addAll({'/alpha.txt', '/beta.txt'});
    state.lastSelectedIndex = 1;
    var builds = 0;

    final result = controller.handleListKeyEvent(
      FocusNode(),
      KeyDownEvent(
        timeStamp: Duration.zero,
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
      ),
      entries,
      () => builds++,
      () {},
      () {},
      () {},
      () {},
      () {},
    );

    expect(result, KeyEventResult.handled);
    expect(state.selectedPaths, isEmpty);
    expect(state.lastSelectedIndex, isNull);
    expect(builds, 1);
  });
}
