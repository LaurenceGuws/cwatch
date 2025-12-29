import 'package:flutter/widgets.dart';

import '../../core/navigation/shell_module.dart';
import '../../shared/theme/nerd_fonts.dart';
import 'services/wsl_service.dart';
import 'ui/wsl_home.dart';

class WslModule extends ShellModuleView {
  const WslModule();

  @override
  String get id => 'wsl';

  @override
  String get label => 'WSL';

  @override
  NerdIcon get icon => NerdIcon.penguin;

  @override
  Widget build(BuildContext context, Widget leading) {
    return WslHome(leading: leading, service: createWslService());
  }
}
