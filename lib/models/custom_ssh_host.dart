class CustomSshHost {
  const CustomSshHost({
    required this.name,
    required this.hostname,
    this.port = 22,
    this.user,
    this.identityFile,
  });

  final String name;
  final String hostname;
  final int port;
  final String? user;
  final String? identityFile;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'hostname': hostname,
      'port': port,
      if (user != null) 'user': user,
      if (identityFile != null) 'identityFile': identityFile,
    };
  }

  factory CustomSshHost.fromJson(Map<String, dynamic> json) {
    return CustomSshHost(
      name: json['name'] as String,
      hostname: json['hostname'] as String,
      port: (json['port'] as num?)?.toInt() ?? 22,
      user: json['user'] as String?,
      identityFile: json['identityFile'] as String?,
    );
  }

  CustomSshHost copyWith({
    String? name,
    String? hostname,
    int? port,
    String? user,
    String? identityFile,
  }) {
    return CustomSshHost(
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      user: user ?? this.user,
      identityFile: identityFile ?? this.identityFile,
    );
  }
}

