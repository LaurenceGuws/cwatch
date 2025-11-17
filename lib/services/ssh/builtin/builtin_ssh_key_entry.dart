import 'dart:convert';

class BuiltInSshKeyEntry {
  const BuiltInSshKeyEntry({
    required this.id,
    required this.label,
    required this.fingerprint,
    required this.createdAt,
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  final String id;
  final String label;
  final String fingerprint;
  final DateTime createdAt;
  final String salt;
  final String nonce;
  final String ciphertext;
  final String mac;

  List<int> get saltBytes => base64.decode(salt);
  List<int> get nonceBytes => base64.decode(nonce);
  List<int> get ciphertextBytes => base64.decode(ciphertext);
  List<int> get macBytes => base64.decode(mac);

  Map<String, dynamic> toJson() => {
        'version': 1,
        'id': id,
        'label': label,
        'fingerprint': fingerprint,
        'createdAt': createdAt.toIso8601String(),
        'salt': salt,
        'nonce': nonce,
        'ciphertext': ciphertext,
        'mac': mac,
      };

  factory BuiltInSshKeyEntry.fromJson(Map<String, dynamic> json) {
    return BuiltInSshKeyEntry(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Unnamed key',
      fingerprint: json['fingerprint'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      salt: json['salt'] as String? ?? '',
      nonce: json['nonce'] as String? ?? '',
      ciphertext: json['ciphertext'] as String? ?? '',
      mac: json['mac'] as String? ?? '',
    );
  }
}
