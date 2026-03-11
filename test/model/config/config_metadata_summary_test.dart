import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/config/config_metadata_summary.dart';

void main() {
  test('buildConfigMetadataSummary renders grouped config metadata', () {
    final summary = buildConfigMetadataSummary();

    expect(summary, contains('[shellPreferences] Shell Preferences'));
    expect(
      summary,
      contains(
        '- sidebarWidth (sidebarWidth): Sidebar Width [doubleValue] unit=px',
      ),
    );
    expect(summary, contains('[editorPreferences] Editor Preferences'));
    expect(
      summary,
      contains(
        '- fontSize (fontSize): Font Size [doubleValue] unit=pt default=14',
      ),
    );
    expect(summary, contains('[terminalPreferences] Terminal Preferences'));
    expect(
      summary,
      contains('- themeDark (themeDark): Dark Theme [string] default=dracula'),
    );
    expect(summary, contains('[explorerPreferences] Explorer Preferences'));
    expect(
      summary,
      contains(
        '- showBreadcrumbs (showBreadcrumbs): Show Breadcrumbs [boolean] default=true',
      ),
    );
  });
}
