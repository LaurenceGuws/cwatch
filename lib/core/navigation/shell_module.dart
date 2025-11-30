import 'package:flutter/widgets.dart';

import '../../ui/theme/nerd_fonts.dart';

/// Describes a pluggable shell section (e.g., servers, docker, k8s, settings).
class ShellModule {
  const ShellModule({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.isPrimary = true,
  });

  /// Stable identifier persisted in settings (e.g., 'servers').
  final String id;
  final String label;
  final NerdIcon icon;
  final bool isPrimary;

  /// Builds the root widget for the module, receiving the shell-leading widget.
  final Widget Function(BuildContext context, Widget leading) builder;
}
