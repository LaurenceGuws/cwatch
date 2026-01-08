import 'tab_state.dart';

abstract class WorkspaceState {
  List<TabState> get tabs;
  int get selectedIndex;
  String get signature;
  
  Map<String, dynamic> toJson();
}
