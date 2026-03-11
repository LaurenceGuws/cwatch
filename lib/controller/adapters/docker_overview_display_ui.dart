abstract class DockerOverviewDisplayUi {
  void showSnackBar(String message);

  Future<void> showLogsDialog({
    required String title,
    required String logs,
  });

  Future<void> showErrorDialog({
    required String title,
    required String message,
  });

  Future<void> showInspectDialog({
    required String title,
    required String content,
  });

  Future<void> copyToClipboard(
    String value, {
    required String successMessage,
  });
}
