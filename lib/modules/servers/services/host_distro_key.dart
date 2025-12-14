import 'package:cwatch/models/ssh_host.dart';

String hostDistroCacheKey(SshHost host) =>
    '${host.hostname}:${host.port}:${host.user ?? ''}';
