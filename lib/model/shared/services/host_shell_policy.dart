import 'package:cwatch/model/models/ssh_host.dart';

const Set<String> _noShellHosts = {
  'github.com',
  'ssh.github.com',
  'bitbucket.org',
  'altssh.bitbucket.org',
  'gh',
  'bb',
};

bool isNoShellHost(SshHost host) {
  final hostname = host.hostname.trim().toLowerCase();
  final name = host.name.trim().toLowerCase();
  bool matches(String value) =>
      _noShellHosts.contains(value) ||
      _noShellHosts.any((entry) => value.endsWith('.$entry'));
  return matches(hostname) || matches(name);
}
