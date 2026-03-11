import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/view/core/widgets/keep_alive.dart';

import 'tab_view_registry.dart';

class WorkspaceTabRegistryBuilder {
  const WorkspaceTabRegistryBuilder();

  TabViewRegistry<WorkspaceTab> build({required String viewKeyPrefix}) {
    return TabViewRegistry<WorkspaceTab>(
      tabId: (tab) => tab.id,
      keepAliveBuilder: (child, key) =>
          KeepAliveWrapper(key: key, child: child),
      viewKeyPrefix: viewKeyPrefix,
    );
  }
}
