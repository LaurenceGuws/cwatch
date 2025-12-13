import 'dart:convert';

class BuiltInSshKeyEntry {
  const BuiltInSshKeyEntry({
    required this.id,
    required this.label,
    required this.fingerprint,
    required this.createdAt,
    required this.isEncrypted,
    required this.keyHasPassphrase,
    this.salt,
    this.nonce,
    this.ciphertext,
    this.mac,
    this.plaintext,
  }) : assert(
         isEncrypted
             ? (salt != null &&
                   nonce != null &&
                   ciphertext != null &&
                   mac != null &&
                   plaintext == null)
             : (plaintext != null &&
                   salt == null &&
                   nonce == null &&
                   ciphertext == null &&
                   mac == null),
         'Encrypted keys must have salt/nonce/ciphertext/mac, '
         'unencrypted keys must have plaintext',
       );

  final String id;
  final String label;
  final String fingerprint;
  final DateTime createdAt;
  final bool isEncrypted; // Whether our storage is encrypted
  final bool keyHasPassphrase; // Whether the SSH key itself has a passphrase
  final String? salt;
  final String? nonce;
  final String? ciphertext;
  final String? mac;
  final String? plaintext;

  List<int> get saltBytes => salt != null ? base64.decode(salt!) : [];
  List<int> get nonceBytes => nonce != null ? base64.decode(nonce!) : [];
  List<int> get ciphertextBytes =>
      ciphertext != null ? base64.decode(ciphertext!) : [];
  List<int> get macBytes => mac != null ? base64.decode(mac!) : [];

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'version': 2,
      'id': id,
      'label': label,
      'fingerprint': fingerprint,
      'createdAt': createdAt.toIso8601String(),
      'isEncrypted': isEncrypted,
      'keyHasPassphrase': keyHasPassphrase,
    };
    if (isEncrypted) {
      json.addAll({
        'salt': salt!,
        'nonce': nonce!,
        'ciphertext': ciphertext!,
        'mac': mac!,
      });
    } else {
      json['plaintext'] = plaintext!;
    }
    return json;
  }

  factory BuiltInSshKeyEntry.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    final isEncrypted =
        json['isEncrypted'] as bool? ??
        (version == 1); // Legacy entries are always encrypted
    final keyHasPassphrase = json['keyHasPassphrase'] as bool? ?? false;

    if (isEncrypted) {
      return BuiltInSshKeyEntry(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Unnamed key',
        fingerprint: json['fingerprint'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        isEncrypted: true,
        keyHasPassphrase: keyHasPassphrase,
        salt: json['salt'] as String? ?? '',
        nonce: json['nonce'] as String? ?? '',
        ciphertext: json['ciphertext'] as String? ?? '',
        mac: json['mac'] as String? ?? '',
      );
    } else {
      return BuiltInSshKeyEntry(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Unnamed key',
        fingerprint: json['fingerprint'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        isEncrypted: false,
        keyHasPassphrase: keyHasPassphrase,
        plaintext: json['plaintext'] as String? ?? '',
      );
    }
  }
}
