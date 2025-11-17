enum SshClientBackend { platform, builtin }

extension SshClientBackendParsing on SshClientBackend {
  static SshClientBackend fromJson(String? value) {
    switch (value) {
      case 'builtin':
        return SshClientBackend.builtin;
      case 'platform':
      default:
        return SshClientBackend.platform;
    }
  }
}
