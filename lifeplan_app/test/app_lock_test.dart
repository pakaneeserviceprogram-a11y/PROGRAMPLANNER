import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/app_lock.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/app_settings_repository.dart';
import 'package:lifeplan_app/models/app_settings.dart';
import 'package:lifeplan_app/screens/privacy_screen.dart';
import 'package:lifeplan_app/widgets/app_lock_gate.dart';

/// ล็อกแอปด้วยลายนิ้วมือ/PIN ของมือถือ
void main() {
  var nextResult = AppLockResult.unlocked;
  var authCalls = 0;

  setUp(() async {
    authCalls = 0;
    nextResult = AppLockResult.unlocked;
    AppLock.debugIsAvailable = () async => true;
    AppLock.debugAuthenticate = () async {
      authCalls++;
      return nextResult;
    };
    await setUpTestHive();
    await Hive.openBox<Map>(HiveBoxes.appSettings, bytes: Uint8List(0));
  });

  tearDown(() async {
    AppLock.debugIsAvailable = null;
    AppLock.debugAuthenticate = null;
    await Hive.close();
    await tearDownTestHive();
  });

  test('ผู้ใช้เดิมที่อัปเดตมา (ไม่มีคีย์) ได้ล็อกเป็นค่าเริ่มต้น', () {
    expect(AppSettings.fromMap({}).appLockEnabled, isTrue);
    expect(AppSettings.fromMap(const AppSettings(appLockEnabled: false).toMap()).appLockEnabled, isFalse);
  });

  Widget app({required bool locked}) => MaterialApp(
        home: AppLockGate(
          deviceSupported: true,
          lockedAtStart: locked,
          child: const Scaffold(body: Text('ข้อมูลลูกค้าลับ')),
        ),
      );

  testWidgets('เปิดแอปแล้วขอปลดล็อกทันที ปลดสำเร็จจึงเห็นข้อมูล', (tester) async {
    nextResult = AppLockResult.canceled;
    await tester.pumpWidget(app(locked: true));
    await tester.pumpAndSettle();

    expect(authCalls, 1);
    expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);
    // ข้อมูลข้างใต้ถูกบังและกดไม่ได้
    expect(find.text('ข้อมูลลูกค้าลับ').hitTestable(), findsNothing);

    nextResult = AppLockResult.unlocked;
    await tester.tap(find.byKey(const ValueKey('app-unlock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsNothing);
    expect(find.text('ข้อมูลลูกค้าลับ').hitTestable(), findsOneWidget);
  });

  testWidgets('ปลดล็อกไม่ผ่านแสดงข้อความ และยังล็อกอยู่', (tester) async {
    nextResult = AppLockResult.failed;
    await tester.pumpWidget(app(locked: true));
    await tester.pumpAndSettle();
    expect(find.text('ปลดล็อกไม่สำเร็จ ลองอีกครั้ง'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);
  });

  testWidgets('เครื่องถอดล็อกหน้าจอออกแล้ว ปล่อยเข้าแอป ไม่ให้ติดอยู่นอกแอป', (tester) async {
    nextResult = AppLockResult.notAvailable;
    await tester.pumpWidget(app(locked: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsNothing);
  });

  testWidgets('ออกจากแอปเกิน 30 วินาทีแล้วกลับมา ต้องปลดล็อกใหม่ / ออกแป๊บเดียวไม่ต้อง', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppLockGate(
        deviceSupported: true,
        relockAfter: Duration.zero,
        child: const Scaffold(body: Text('ข้อมูลลูกค้าลับ')),
      ),
    ));
    expect(find.byKey(const ValueKey('app-lock-screen')), findsNothing);

    nextResult = AppLockResult.canceled;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);
    expect(authCalls, 1);
  });

  testWidgets('ปิดล็อกในตั้งค่าแล้ว กลับมาจากพื้นหลังไม่ล็อก', (tester) async {
    await AppSettingsRepository().save(const AppSettings(appLockEnabled: false));
    await tester.pumpWidget(MaterialApp(
      home: AppLockGate(
        deviceSupported: true,
        relockAfter: Duration.zero,
        child: const Scaffold(body: Text('ข้อมูลลูกค้าลับ')),
      ),
    ));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsNothing);
    expect(authCalls, 0);
  });

  group('หน้าความเป็นส่วนตัว', () {
    testWidgets('ปิดล็อกต้องยืนยันตัวตนก่อน ยกเลิกแล้วล็อกยังเปิดอยู่', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));
      await tester.pumpAndSettle();

      nextResult = AppLockResult.canceled;
      await tester.tap(find.byKey(const ValueKey('app-lock-switch')));
      await tester.pumpAndSettle();
      expect(AppSettingsRepository().get().appLockEnabled, isTrue);

      nextResult = AppLockResult.unlocked;
      await tester.tap(find.byKey(const ValueKey('app-lock-switch')));
      await tester.pumpAndSettle();
      expect(authCalls, 2);
      expect(AppSettingsRepository().get().appLockEnabled, isFalse);
    });

    testWidgets('เครื่องที่ไม่มีล็อกหน้าจอ บอกให้ไปตั้งก่อน และกดสวิตช์ไม่ได้', (tester) async {
      AppLock.debugIsAvailable = () async => false;
      await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-lock-unavailable')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('app-lock-switch')));
      await tester.pumpAndSettle();
      expect(authCalls, 0);
    });
  });
}
