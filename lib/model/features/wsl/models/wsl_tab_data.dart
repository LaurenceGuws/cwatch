import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/models/wsl_workspace_state.dart';

class WslTabData {
  const WslTabData({required this.kind, required this.persistedState});

  final WslTabKind kind;
  final TabState persistedState;
}
