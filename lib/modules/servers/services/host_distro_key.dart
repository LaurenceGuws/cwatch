import 'package:cwatch/models/ssh_host.dart';

String hostDistroCacheKey(SshHost host) =>
    '${host.hostname}:${host.port}:${host.user ?? ''}';

String hostDisableKey(SshHost host) =>
    '${host.name.toLowerCase()}|${host.hostname.toLowerCase()}|${host.port}|${host.user ?? ''}';

String canonicalDisabledHostKey(SshHost host) => host.name.toLowerCase();

bool disabledKeyMatchesHost(String key, SshHost host) {
  final normalized = key.toLowerCase();
  final name = host.name.toLowerCase();
  final hostname = host.hostname.toLowerCase();
  final port = host.port;
  final user = (host.user ?? '').toLowerCase();
  final disableKey = '$name|$hostname|$port|$user';
  final disablePrefix = '$name|$hostname|$port';
  final distroKey = '$hostname:$port:$user';
  final distroPrefix = '$hostname:$port';

  if (normalized == name ||
      normalized == disableKey ||
      normalized == disablePrefix ||
      normalized == distroKey ||
      normalized == distroPrefix) {
    return true;
  }
  if (normalized.startsWith('$disablePrefix|') ||
      normalized.startsWith('$distroPrefix:')) {
    return true;
  }
  return false;
}
