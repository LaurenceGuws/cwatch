import 'package:flutter/widgets.dart';

import '../../core/navigation/shell_module.dart';
import '../../shared/theme/nerd_fonts.dart';
import 'ui/experimental_view.dart';

class ExperimentalModule extends ShellModuleView {
  const ExperimentalModule();

  @override
  String get id => 'experimental';

  @override
  String get label => 'Experimental';

  @override
  NerdIcon get icon => NerdIcon.fileCode;

  @override
  bool get isPrimary => false;

  @override
  Widget build(BuildContext context, Widget leading) {
    return ExperimentalView(leading: leading);
  }
}
