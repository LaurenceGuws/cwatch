import 'wsl_distribution.dart';
import 'wsl_service_interface.dart';

WslService createWslServiceImpl() => _StubWslService();

class _StubWslService implements WslService {
  @override
  Future<List<WslDistribution>> listDistributions() async => const [];
}
