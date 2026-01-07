import '../../../../../models/remote_file_entry.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import 'file_entry_list.dart';

class ExplorerState {
  final List<RemoteFileEntry> entries = [];
  final Map<String, LocalFileSession> localEdits = {};
  final Set<String> syncingPaths = {};
  final Set<String> refreshingPaths = {};
  final Set<String> pathHistory = {'/'};

  bool searchActive = false;
  String searchQuery = '';
  String searchInclude = '';
  String searchExclude = '';
  bool searchMatchCase = false;
  bool searchMatchWholeWord = false;
  bool searchContents = false;
  bool showRowHeightControl = false;
  double rowHeight = 36;
  int searchGeneration = 0;
  RemoteCommandCancellation? searchCancellation;

  bool loading = true;
  String? error;
  bool showBreadcrumbs = true;
}
