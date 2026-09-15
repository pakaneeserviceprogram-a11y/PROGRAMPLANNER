import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/seed_data.dart';
import 'package:lifeplan_app/main.dart';

/// Skips Google Fonts' network fetch, which never resolves on a
/// network-isolated test runner and leaves a pending Future behind.
final _testTheme = ThemeData(useMaterial3: true);

void main() {
  setUp(() async {
    await setUpTestHive();
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.userProfile),
      Hive.openBox<Map>(HiveBoxes.workTasks),
      Hive.openBox<Map>(HiveBoxes.exerciseItems),
      Hive.openBox<Map>(HiveBoxes.clients),
      Hive.openBox<Map>(HiveBoxes.financeTransactions),
      Hive.openBox<Map>(HiveBoxes.skillTracks),
      Hive.openBox<Map>(HiveBoxes.scheduleEvents),
      Hive.openBox<Map>(HiveBoxes.learningStreak),
      Hive.openBox<Map>(HiveBoxes.goalSettings),
    ]);
    await SeedData.seedIfEmpty();
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(LifePlanApp(theme: _testTheme));
    await tester.pumpAndSettle();

    expect(find.text('LifePlan'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsWidgets);
    expect(find.text('ดำเนินการต่อด้วย Google'), findsOneWidget);
    expect(find.text('ดำเนินการต่อด้วย Apple'), findsOneWidget);
  });

  // Multi-step "sign in, tap into a module, add a record" flows are covered
  // by test/repository_test.dart (real persistence, no UI) plus a manual
  // click-through of `flutter build web` — see README.md. `testWidgets`
  // runs inside a FakeAsync zone that doesn't reliably resolve Hive's real
  // file I/O, which made deeper interaction tests here flaky/slow rather
  // than a trustworthy signal.
}
