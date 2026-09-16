import 'dart:async';

import 'package:flutter/material.dart';

import 'data/hive_boxes.dart';
import 'data/notifications.dart';
import 'data/repositories/user_repository.dart';
import 'data/seed_data.dart';
import 'screens/auth/login_screen.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';
import 'widgets/reminder_popup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  await SeedData.seedIfEmpty();
  // ตั้งการเตือนใหม่ตามตารางล่าสุด (ไม่ await เพื่อไม่ให้หน่วงการเปิดแอป —
  // ถ้าผู้ใช้ปิดการเตือนไว้ ฟังก์ชันนี้จะแค่ล้างของเก่าแล้วจบ)
  unawaited(NotificationService.syncScheduleReminders());
  runApp(const LifePlanApp());
}

class LifePlanApp extends StatefulWidget {
  /// Overridable so widget tests can skip the network-fetched Google Fonts
  /// theme (see test/widget_test.dart) — the real app always uses the
  /// default (AppTheme.light).
  final ThemeData? theme;

  const LifePlanApp({super.key, this.theme});

  @override
  State<LifePlanApp> createState() => _LifePlanAppState();
}

class _LifePlanAppState extends State<LifePlanApp> {
  /// ป๊อปอัปเตือนต้องเปิดได้จากทุกหน้า รวมถึงตอนที่ไม่มี context ของหน้าไหนอยู่ในมือ
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final loggedIn = UserRepository().getCurrent() != null;
    return MaterialApp(
      title: 'LifePlan',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: widget.theme ?? AppTheme.light,
      builder: (context, child) => ReminderHost(
        navigatorKey: _navigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),
      home: loggedIn ? const RootShell() : const LoginScreen(),
    );
  }
}
