import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'backup.dart';

/// เข้ารหัสไฟล์สำรองด้วยรหัสผ่าน — ไฟล์สำรองมีข้อมูลลูกค้าครบทุกราย และมักถูกส่งเข้า LINE/Drive
/// จึงเป็นจุดที่ข้อมูลหลุดง่ายที่สุด
///
/// AES-256-GCM (ตรวจได้ทั้งรหัสผิดและไฟล์ถูกแก้) กุญแจได้จากรหัสผ่านด้วย PBKDF2-SHA256
/// ไม่มีทางกู้ไฟล์ถ้าลืมรหัส — ตั้งใจให้เป็นแบบนั้น
class BackupCrypto {
  BackupCrypto._();

  static const format = 'lifeplan-backup-encrypted';
  static const minPasswordLength = 6;

  /// รอบ PBKDF2 — มากพอให้เดารหัสช้า แต่ยังเข้ารหัสบนมือถือได้ในไม่กี่วินาที
  /// (เก็บในไฟล์ด้วย ปรับขึ้นภายหลังได้โดยไฟล์เก่ายังเปิดได้)
  static int iterations = 150000;

  static final _cipher = AesGcm.with256bits();

  static bool isEncrypted(String text) {
    try {
      final decoded = jsonDecode(text);
      return decoded is Map && decoded['format'] == format;
    } catch (_) {
      return false;
    }
  }

  static Future<SecretKey> _keyFor(String password, List<int> salt, int rounds) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: rounds, bits: 256)
          .deriveKeyFromPassword(password: password, nonce: salt);

  /// PBKDF2 ใช้เวลาราว 1–3 วินาที — ทำใน isolate แยก หน้าจอจะได้ไม่ค้าง (เว็บทำในเธรดเดิม)
  static Future<String> encrypt(String plainJson, String password) async {
    if (password.length < minPasswordLength) {
      throw const BackupException('รหัสผ่านต้องยาวอย่างน้อย $minPasswordLength ตัวอักษร');
    }
    return compute(_encryptJob, (plainJson, password, iterations));
  }

  static Future<String> _encryptJob((String, String, int) job) async {
    final (plainJson, password, iterations) = job;
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _keyFor(password, salt, iterations);
    final box = await _cipher.encrypt(utf8.encode(plainJson), secretKey: key, nonce: _cipher.newNonce());

    return jsonEncode({
      'format': format,
      'version': 1,
      'kdf': 'pbkdf2-sha256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'cipher': 'aes-256-gcm',
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText),
    });
  }

  /// คืน JSON ไฟล์สำรองปกติ — รหัสผิดหรือไฟล์ถูกแก้ โยน [BackupException]
  static Future<String> decrypt(String encryptedText, String password) =>
      compute(_decryptJob, (encryptedText, password));

  static Future<String> _decryptJob((String, String) job) async {
    final (encryptedText, password) = job;
    final Map map;
    try {
      map = jsonDecode(encryptedText) as Map;
    } catch (_) {
      throw const BackupException('ไฟล์สำรองเสียหาย อ่านไม่ได้');
    }
    if (map['format'] != format) throw const BackupException('ไฟล์นี้ไม่ใช่ไฟล์สำรองที่เข้ารหัส');
    if ((map['version'] as num?) != 1) {
      throw const BackupException('ไฟล์สำรองมาจากแอปเวอร์ชันใหม่กว่า — กรุณาอัปเดตแอปก่อน');
    }

    try {
      final key = await _keyFor(password, base64Decode(map['salt'] as String), (map['iterations'] as num).toInt());
      final clear = await _cipher.decrypt(
        SecretBox(
          base64Decode(map['data'] as String),
          nonce: base64Decode(map['nonce'] as String),
          mac: Mac(base64Decode(map['mac'] as String)),
        ),
        secretKey: key,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const BackupException('รหัสผ่านไม่ถูกต้อง');
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException('ไฟล์สำรองเสียหาย อ่านไม่ได้');
    }
  }
}
