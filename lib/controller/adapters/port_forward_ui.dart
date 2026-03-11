import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';

abstract class PortForwardUi {
  Future<List<PortForwardRequest>?> showPortForwardDialog({
    required String title,
    required List<PortForwardRequest> requests,
    required Future<bool> Function(int port) portValidator,
    required List<ActivePortForward> active,
  });

  void showSnackBar(String message);
}
