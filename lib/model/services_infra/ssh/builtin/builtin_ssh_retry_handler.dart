import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';
import 'package:dartssh2/dartssh2.dart';

import '../remote_shell_base.dart';
import 'builtin_ssh_auth_challenge_handler.dart';
import 'builtin_ssh_exceptions.dart';
import 'builtin_ssh_failure_mapper.dart';
import 'builtin_ssh_logging.dart';

class BuiltInSshRetryHandler {
  const BuiltInSshRetryHandler({
    required BuiltInSshFailureMapper failureMapper,
    required BuiltInSshAuthChallengeHandler authChallengeHandler,
  }) : _failureMapper = failureMapper,
       _authChallengeHandler = authChallengeHandler;

  final BuiltInSshFailureMapper _failureMapper;
  final BuiltInSshAuthChallengeHandler _authChallengeHandler;

  Future<T> run<T>(SshHost host, Future<T> Function() action) async {
    var retries = 0;
    while (true) {
      try {
        if (isNoShellHost(host)) {
          throw NoShellHostException(host);
        }
        return await action();
      } on SSHAuthFailError catch (error) {
        logBuiltInSshWarning(
          'Authentication failed for ${host.name}',
          error: error,
        );
        throw _failureMapper.map(
          host,
          BuiltInSshAuthenticationFailed(
            hostName: host.name,
            message: error.toString(),
          ),
        );
      } on SSHStateError catch (error) {
        logBuiltInSshWarning('SSH state error for ${host.name}', error: error);
        throw _failureMapper.map(
          host,
          Exception('SSH connection failed for ${host.name}: $error'),
        );
      } catch (error) {
        logBuiltInSshWarning(
          'SSH operation failed for ${host.name}',
          error: error,
        );
        if (error is BuiltInSshKeyDecryptionRequired) {
          if (retries > 2) rethrow;
          final decrypted = await _authChallengeHandler.handleDecryptRequired(
            error,
          );
          retries++;
          if (decrypted) {
            continue;
          }
        } else if (error is BuiltInSshKeyPassphraseRequired) {
          if (retries > 2) rethrow;
          final provided = await _authChallengeHandler.handleBuiltInPassphrase(
            error,
          );
          retries++;
          if (provided) {
            continue;
          }
        } else if (error is BuiltInSshIdentityPassphraseRequired) {
          if (retries > 2) rethrow;
          final provided = await _authChallengeHandler.handleIdentityPassphrase(
            error,
          );
          retries++;
          if (provided) {
            continue;
          }
        } else if (error is BuiltInSshKeyUnsupportedCipher ||
            error is NoShellHostException) {
          rethrow;
        }
        logBuiltInSshWarning(
          'Error in SSH operation for ${host.name}',
          error: error,
        );
        throw _failureMapper.map(host, error);
      }
    }
  }
}
