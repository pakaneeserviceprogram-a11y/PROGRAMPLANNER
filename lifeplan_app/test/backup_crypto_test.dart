import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:lifeplan_app/data/backup.dart';
import 'package:lifeplan_app/data/backup_crypto.dart';

/// ไฟล์สำรองเข้ารหัสด้วยรหัสผ่าน
void main() {
  // รอบน้อยในเทสต์ให้เร็ว — ไฟล์เก็บจำนวนรอบไว้เอง ตอนถอดใช้ค่าจากไฟล์
  setUpAll(() => BackupCrypto.iterations = 1000);

  const plain = '{"app":"lifeplan","version":1,"data":{"clients":{"c1":{"name":"คุณสมชาย ใจดี"}}}}';

  test('เข้ารหัสแล้วถอดกลับได้ข้อมูลเดิม และในไฟล์ไม่มีข้อมูลลูกค้าให้อ่านได้', () async {
    final encrypted = await BackupCrypto.encrypt(plain, 'รหัสลับ123');
    expect(BackupCrypto.isEncrypted(encrypted), isTrue);
    expect(encrypted, isNot(contains('สมชาย')));
    expect(utf8.decode(base64Decode(jsonDecode(encrypted)['data'] as String), allowMalformed: true),
        isNot(contains('สมชาย')));
    expect(await BackupCrypto.decrypt(encrypted, 'รหัสลับ123'), plain);
  });

  test('รหัสผิดบอกว่ารหัสผ่านไม่ถูกต้อง', () async {
    final encrypted = await BackupCrypto.encrypt(plain, 'correct-horse');
    expect(
      () => BackupCrypto.decrypt(encrypted, 'wrong-horse'),
      throwsA(isA<BackupException>().having((e) => e.message, 'message', 'รหัสผ่านไม่ถูกต้อง')),
    );
  });

  test('ไฟล์ถูกแก้กลางทางจับได้ ไม่กู้ข้อมูลเพี้ยนเข้าเครื่อง', () async {
    final map = jsonDecode(await BackupCrypto.encrypt(plain, 'password1')) as Map<String, dynamic>;
    final data = base64Decode(map['data'] as String);
    data[0] ^= 0xFF;
    map['data'] = base64Encode(data);
    expect(() => BackupCrypto.decrypt(jsonEncode(map), 'password1'), throwsA(isA<BackupException>()));
  });

  test('ตั้งรหัสสั้นเกินไปไม่ได้', () {
    expect(() => BackupCrypto.encrypt(plain, '12345'), throwsA(isA<BackupException>()));
  });

  test('ไฟล์สำรองแบบเก่า (ไม่เข้ารหัส) ไม่ถูกมองว่าเข้ารหัส จึงกู้คืนได้ตามเดิม', () {
    expect(BackupCrypto.isEncrypted(plain), isFalse);
    expect(BackupCrypto.isEncrypted('ไม่ใช่ JSON'), isFalse);
  });

  test('ไฟล์ที่ทำด้วยจำนวนรอบอื่นยังเปิดได้ (ใช้ค่าที่เก็บในไฟล์)', () async {
    final encrypted = await BackupCrypto.encrypt(plain, 'password1');
    BackupCrypto.iterations = 2000;
    addTearDown(() => BackupCrypto.iterations = 1000);
    expect(await BackupCrypto.decrypt(encrypted, 'password1'), plain);
  });
}
