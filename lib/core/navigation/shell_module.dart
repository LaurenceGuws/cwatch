import 'package:flutter/widgets.dart';

import '../../shared/theme/nerd_fonts.dart';

class ShellAction {
  const ShellAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final NerdIcon icon;
  final VoidCallback onSelected;
  final bool enabled;
}

/// Describes a pluggable shell section (e.g., servers, docker, k8s, settings).
abstract class ShellModuleView {
  const ShellModuleView();

  String get id;
  String get label;
  NerdIcon get icon;
  bool get isPrimary => true;

  /// Builds the root widget for the module, receiving the shell-leading widget.
  Widget build(BuildContext context, Widget leading);

  /// Optional actions contributed to the shell chrome (sidebar/bottom menu).
  List<ShellAction> get actions => const [];
}

class ShellModule implements ShellModuleView {
  const ShellModule({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.isPrimary = true,
    this.actions = const [],
  });

  @override
  final String id;
  @override
  final String label;
  @override
  final NerdIcon icon;
  @override
  final bool isPrimary;
  final Widget Function(BuildContext context, Widget leading) builder;
  @override
  final List<ShellAction> actions;

  @override
  Widget build(BuildContext context, Widget leading) =>
      builder(context, leading);
}
