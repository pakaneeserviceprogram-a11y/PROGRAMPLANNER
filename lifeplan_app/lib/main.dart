import 'package:flutter/material.dart';

import 'data/hive_boxes.dart';
import 'data/repositories/user_repository.dart';
import 'data/seed_data.dart';
import 'screens/auth/login_screen.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  await SeedData.seedIfEmpty();
  runApp(const LifePlanApp());
}

class LifePlanApp extends StatelessWidget {
  /// Overridable so widget tests can skip the network-fetched Google Fonts
  /// theme (see test/widget_test.dart) — the real app always uses the
  /// default (AppTheme.light).
  final ThemeData? theme;

  const LifePlanApp({super.key, this.theme});

  @override
  Widget build(BuildContext context) {
    final loggedIn = UserRepository().getCurrent() != null;
    return MaterialApp(
      title: 'LifePlan',
      debugShowCheckedModeBanner: false,
      theme: theme ?? AppTheme.light,
      home: loggedIn ? const RootShell() : const LoginScreen(),
    );
  }
}
