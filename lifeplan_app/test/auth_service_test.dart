import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/auth/auth_service.dart';
import 'package:lifeplan_app/data/auth/local_auth_service.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/user_repository.dart';
import 'package:lifeplan_app/models/user_profile.dart';
import 'package:lifeplan_app/screens/auth/login_screen.dart';

/// ชั้น AuthService — หน้าจอเรียกผ่านตัวนี้อย่างเดียว การต่อบริการจริงภายหลัง
/// จึงแก้แค่ implementation ตัวเดียว (ดูขั้นตอนใน lib/data/auth/auth_service.dart)
void main() {
  setUp(() async {
    await setUpTestHive();
    await Hive.openBox<Map>(HiveBoxes.userProfile, bytes: Uint8List(0));
  });

  tearDown(() async {
    AuthService.instance = LocalAuthService();
    await Hive.close();
    await tearDownTestHive();
  });

  group('AuthValidation', () {
    test('อีเมลต้องมีรูปแบบถูกต้อง', () {
      expect(AuthValidation.email(''), 'กรุณากรอกอีเมล');
      expect(AuthValidation.email('ไม่ใช่อีเมล'), 'รูปแบบอีเมลไม่ถูกต้อง');
      expect(AuthValidation.email('me@example'), 'รูปแบบอีเมลไม่ถูกต้อง');
      expect(AuthValidation.email(' me@example.com '), isNull);
    });

    test('รหัสผ่านสั้นกว่า 8 ตัวไม่ผ่าน และยืนยันต้องตรงกัน', () {
      expect(AuthValidation.password('1234567'), isNotNull);
      expect(AuthValidation.password('12345678'), isNull);
      expect(AuthValidation.passwordConfirm('12345678', '1234567x'), 'รหัสผ่านไม่ตรงกัน');
      expect(AuthValidation.passwordConfirm('12345678', '12345678'), isNull);
    });
  });

  group('LocalAuthService', () {
    test('สมัครแล้วได้บัญชีที่บันทึกลงเครื่องจริง', () async {
      final auth = LocalAuthService();
      final result = await auth.registerWithEmail(name: ' สมชาย ', email: ' somchai@example.com ', password: 'supersecret');

      expect(result.isSuccess, isTrue);
      expect(result.user!.name, 'สมชาย');
      expect(result.user!.email, 'somchai@example.com');
      expect(UserRepository().getCurrent()!.id, result.user!.id);
      expect(auth.currentUser()!.email, 'somchai@example.com');
    });

    test('ข้อมูลไม่ครบได้ข้อความบอก และไม่สร้างบัญชี', () async {
      final auth = LocalAuthService();
      expect((await auth.registerWithEmail(name: '', email: 'a@b.com', password: 'supersecret')).errorMessage, 'กรุณากรอกชื่อ');
      expect((await auth.registerWithEmail(name: 'ก', email: 'a@b.com', password: '123')).errorMessage, isNotNull);
      expect((await auth.signInWithEmail(email: '', password: 'supersecret')).errorMessage, 'กรุณากรอกอีเมล');
      expect(UserRepository().getCurrent(), isNull);
    });

    test('ล็อกอินด้วยอีเมลเดิมได้บัญชีเดิม (ชื่อที่ตั้งไว้ไม่หาย)', () async {
      final auth = LocalAuthService();
      final created = (await auth.registerWithEmail(name: 'สมชาย', email: 'somchai@example.com', password: 'supersecret')).user!;

      final again = await auth.signInWithEmail(email: 'SOMCHAI@example.com', password: 'supersecret');
      expect(again.user!.id, created.id);
      expect(again.user!.name, 'สมชาย');

      // อีเมลอื่น = บัญชีใหม่ (ยังเป็นบัญชีเดียวต่อเครื่อง)
      final other = await auth.signInWithEmail(email: 'other@example.com', password: 'supersecret');
      expect(other.user!.id, isNot(created.id));
    });

    test('ปุ่ม Google/Apple ยังใช้บัญชีในเครื่อง และออกจากระบบแล้วไม่เหลือบัญชี', () async {
      final auth = LocalAuthService();
      final result = await auth.signInWithProvider(AuthProvider.google);
      expect(result.user!.authProvider, AuthProvider.google);

      await auth.signOut();
      expect(auth.currentUser(), isNull);
    });

    test('signInWithProvider ด้วย email ถือเป็นการเรียกผิดวิธี', () async {
      expect((await LocalAuthService().signInWithProvider(AuthProvider.email)).isSuccess, isFalse);
    });
  });

  group('หน้าเข้าสู่ระบบ', () {
    testWidgets('กรอกไม่ครบขึ้นข้อความจาก AuthService และไม่เข้าแอป', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.tap(find.text('เข้าสู่ระบบ'));
      await tester.pump();

      expect(find.text('กรุณากรอกอีเมล'), findsOneWidget);
      expect(UserRepository().getCurrent(), isNull);
    });

    testWidgets('โหมดบัญชีในเครื่องต้องบอกผู้ใช้ว่ายังไม่ใช่การยืนยันตัวตนจริง', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      expect(find.textContaining('โหมดทดลอง'), findsOneWidget);
    });
  });
}
