export 'wsl_distribution.dart';
export 'wsl_service_interface.dart';
import 'wsl_service_interface.dart';
import 'wsl_service_stub.dart'
    if (dart.library.io) 'wsl_service_io.dart';

WslService createWslService() => createWslServiceImpl();
