import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

class FormSpacer extends StatelessWidget {
  const FormSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return SizedBox(height: spacing.lg);
  }
}
