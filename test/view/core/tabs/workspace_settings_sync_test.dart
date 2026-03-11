import 'package:cwatch/view/core/tabs/workspace_settings_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sync = WorkspaceSettingsSync();

  test('handleSettingsChanged restores when signatures differ', () async {
    var restored = false;
    var persisted = false;

    await sync.handleSettingsChanged(
      mounted: true,
      persistedSignature: 'saved',
      currentSignature: 'current',
      restoreWorkspace: () async {
        restored = true;
      },
      persistIfPending: () async {
        persisted = true;
      },
    );

    expect(restored, isTrue);
    expect(persisted, isTrue);
  });

  test('handleSettingsChangedAsync skips work when unmounted', () async {
    var restored = false;
    var persisted = false;

    sync.handleSettingsChangedAsync(
      mounted: false,
      persistedSignature: 'saved',
      currentSignature: 'current',
      restoreWorkspace: () async {
        restored = true;
      },
      persistIfPending: () {
        persisted = true;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(restored, isFalse);
    expect(persisted, isFalse);
  });
}
