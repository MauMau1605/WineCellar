import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:share_plus/share_plus.dart';
import 'package:wine_cellar/features/developer/domain/entities/backup_data.dart';

/// Handles the low-level encryption, serialisation and file I/O for backups.
///
/// Encryption scheme:
///  - AES-256-CBC with a 16-byte IV generated at random for every export.
///  - Key derived from the user's password + random 16-byte salt via PBKDF2
///    (SHA-256, 100 000 iterations), producing a 32-byte key.
///  - The final file is a JSON envelope that contains the base64-encoded salt,
///    IV and cipher-text alongside metadata (version, date, includes_secrets).
class BackupLocalDatasource {
  static const int _backupFormatVersion = 1;
  static const int _pbkdf2Iterations = 100000;
  static const int _keyLength = 32; // 256 bits
  static const int _saltLength = 16;

  // ── Serialisation ──────────────────────────────────────────────────────────

  /// Converts [data] to a plain-text JSON string (before encryption).
  String serialise(BackupData data) {
    return jsonEncode({
      'version': data.version,
      'created_at': data.createdAt.toIso8601String(),
      'includes_secrets': data.secrets != null,
      'config': data.config,
      if (data.secrets != null) 'secrets': data.secrets,
      'wines': data.winesJson,
    });
  }

  /// Parses a plain-text JSON string (after decryption) into [BackupData].
  BackupData deserialise(String plainText) {
    final map = jsonDecode(plainText) as Map<String, dynamic>;
    final rawConfig = map['config'] as Map<String, dynamic>? ?? {};
    final rawSecrets = map['secrets'] as Map<String, dynamic>?;

    return BackupData(
      version: (map['version'] as num?)?.toInt() ?? _backupFormatVersion,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      config: rawConfig.map((k, v) => MapEntry(k, v as String?)),
      secrets: rawSecrets?.map((k, v) => MapEntry(k, v as String?)),
      winesJson: map['wines'] as String? ?? '[]',
    );
  }

  // ── Encryption / Decryption ────────────────────────────────────────────────

  /// Encrypts [plainText] with [password] and returns a JSON-encodable map
  /// containing base64 salt, IV and cipher-text.
  Map<String, String> encrypt(String plainText, String password) {
    final salt = _randomBytes(_saltLength);
    final iv = enc.IV(_randomBytes(16));
    final key = enc.Key(_deriveKey(password, salt));

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return {
      'salt': base64.encode(salt),
      'iv': base64.encode(iv.bytes),
      'data': encrypted.base64,
    };
  }

  /// Decrypts the envelope produced by [encrypt] using [password].
  String decrypt(Map<String, dynamic> envelope, String password) {
    final salt = base64.decode(envelope['salt'] as String);
    final iv = enc.IV(base64.decode(envelope['iv'] as String));
    final key = enc.Key(_deriveKey(password, salt));

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(envelope['data'] as String, iv: iv);
  }

  // ── File I/O ───────────────────────────────────────────────────────────────

  /// Writes the encrypted backup file and shares it via the platform dialog.
  Future<void> writeAndShare(Map<String, String> encryptedEnvelope) async {
    final fileName =
        'wine_cellar_backup_${DateTime.now().millisecondsSinceEpoch}.wce';
    final fileContent = jsonEncode(encryptedEnvelope);

    if (Platform.isAndroid || Platform.isIOS) {
      final tmpDir = await getTemporaryDirectory();
      final file = File('${tmpDir.path}/$fileName');
      await file.writeAsString(fileContent);
      await SharePlus.instance.share(
        ShareParams(
          text: 'Sauvegarde Wine Cellar',
          files: [XFile(file.path)],
          title: fileName,
        ),
      );
      return;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer la sauvegarde',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['wce'],
    );
    if (path == null) return; // user cancelled
    await File(path).writeAsString(fileContent);
  }

  /// Opens a file picker and reads the selected `.wce` file.
  ///
  /// Returns null when the user cancels.
  Future<Map<String, dynamic>?> pickAndRead() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choisir une sauvegarde Wine Cellar',
      type: FileType.custom,
      allowedExtensions: ['wce'],
    );
    if (result == null || result.files.single.path == null) return null;

    final raw = await File(result.files.single.path!).readAsString();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  Uint8List _deriveKey(String password, Uint8List salt) {
    final pbkdf2 = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64));
    pbkdf2.init(
      pc.Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength),
    );
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }
}
