import 'wsl_distribution.dart';

abstract class WslService {
  Future<List<WslDistribution>> listDistributions();
}
