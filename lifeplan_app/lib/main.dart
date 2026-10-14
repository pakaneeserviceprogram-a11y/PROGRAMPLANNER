import 'dart:async';

import 'package:flutter/material.dart';

import 'data/app_lock.dart';
import 'data/hive_boxes.dart';
import 'data/notifications.dart';
import 'data/auth/auth_service.dart';
import 'data/repositories/app_settings_repository.dart';
import 'data/seed_data.dart';
import 'screens/auth/login_screen.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_gate.dart';
import 'widgets/reminder_popup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  await SeedData.seedIfEmpty();
  // ตั้งการเตือนใหม่ตามตารางล่าสุด (ไม่ await เพื่อไม่ให้หน่วงการเปิดแอป —
  // ถ้าผู้ใช้ปิดการเตือนไว้ ฟังก์ชันนี้จะแค่ล้างของเก่าแล้วจบ)
  unawaited(NotificationService.syncScheduleReminders());
  // เช็กก่อน runApp เพื่อให้เฟรมแรกล็อกไว้แล้ว — ข้อมูลลูกค้าไม่โผล่ให้เห็นแวบหนึ่ง
  final lockSupported = await AppLock.isAvailable();
  final lockAtStart = lockSupported && AppSettingsRepository().get().appLockEnabled;
  runApp(LifePlanApp(lockSupported: lockSupported, lockedAtStart: lockAtStart));
}

class LifePlanApp extends StatefulWidget {
  /// Overridable so widget tests can skip the network-fetched Google Fonts
  /// theme (see test/widget_test.dart) — the real app always uses the
  /// default (AppTheme.light).
  final ThemeData? theme;

  /// ล็อกแอป (ดู `AppLockGate`) — ค่าเริ่มต้นปิด เทสต์ที่สร้างแอปตรง ๆ จึงไม่ติดล็อก
  final bool lockSupported;
  final bool lockedAtStart;

  const LifePlanApp({super.key, this.theme, this.lockSupported = false, this.lockedAtStart = false});

  @override
  State<LifePlanApp> createState() => _LifePlanAppState();
}

class _LifePlanAppState extends State<LifePlanApp> {
  /// ป๊อปอัปเตือนต้องเปิดได้จากทุกหน้า รวมถึงตอนที่ไม่มี context ของหน้าไหนอยู่ในมือ
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final loggedIn = AuthService.instance.currentUser() != null;
    return MaterialApp(
      title: 'LifePlan',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: widget.theme ?? AppTheme.light,
      builder: (context, child) => AppLockGate(
        deviceSupported: widget.lockSupported,
        lockedAtStart: widget.lockedAtStart,
        child: ReminderHost(
          navigatorKey: _navigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: loggedIn ? const RootShell() : const LoginScreen(),
    );
  }
}
