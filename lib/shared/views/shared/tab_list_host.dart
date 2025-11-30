import 'package:flutter/material.dart';

import 'package:cwatch/modules/docker/ui/engine_tab.dart';

/// Shared tab-list contract so different views expose the same build inputs.
abstract class TabListHost {
  List<EngineTab> get tabs;
  int get selectedIndex;
  ValueChanged<int> get onSelect;
  ValueChanged<int> get onClose;
  void Function(int oldIndex, int newIndex) get onReorder;
  Widget? get leading;
  VoidCallback? get onAddTab;
}
