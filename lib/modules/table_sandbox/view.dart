import 'package:flutter/widgets.dart';

import '../../core/navigation/shell_module.dart';
import '../../shared/theme/nerd_fonts.dart';
import 'ui/data_table_sandbox_view.dart';

class TableSandboxModule extends ShellModuleView {
  const TableSandboxModule();

  @override
  String get id => 'list-sandbox';

  @override
  String get label => 'List Lab';

  @override
  NerdIcon get icon => NerdIcon.fileCode;

  @override
  bool get isPrimary => false;

  @override
  Widget build(BuildContext context, Widget leading) {
    return DataTableSandboxView(leading: leading);
  }
}

