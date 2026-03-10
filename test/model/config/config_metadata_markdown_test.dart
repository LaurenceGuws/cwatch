import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/config/config_metadata_markdown.dart';

void main() {
  test('buildConfigMetadataMarkdown renders registry as markdown', () {
    final markdown = buildConfigMetadataMarkdown();

    expect(markdown, startsWith('# Config Metadata'));
    expect(markdown, contains('## Shell Preferences'));
    expect(markdown, contains('- Key: `shellPreferences`'));
    expect(markdown, contains('### `sidebarWidth`'));
    expect(markdown, contains('- Field: `sidebarWidth`'));
    expect(markdown, contains('- Type: `doubleValue`'));
    expect(markdown, contains('- Unit: `px`'));
    expect(markdown, contains('## Explorer Preferences'));
    expect(markdown, contains('### `showBreadcrumbs`'));
    expect(markdown, contains('- Default: `true`'));
  });
}
