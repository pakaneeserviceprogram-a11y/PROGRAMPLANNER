import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/meal_repository.dart';
import 'package:lifeplan_app/data/repositories/water_repository.dart';
import 'package:lifeplan_app/models/meal_entry.dart';
import 'package:lifeplan_app/screens/dashboard_screen.dart';

/// คุมว่าการ์ดโภชนาการบนหน้าหลักแสดงตัวเลขของวันนี้ได้จริงและไม่ล้นจอ
/// (box แบบ in-memory เหมือน schedule_screen_test / nutrition_screen_test)
void main() {
  setUp(() async {
    await setUpTestHive();
    await Future.wait([
      for (final name in const [
        HiveBoxes.userProfile,
        HiveBoxes.workTasks,
        HiveBoxes.exerciseItems,
        HiveBoxes.mealEntries,
        HiveBoxes.waterLogs,
        HiveBoxes.sleepEntries,
        HiveBoxes.clients,
        HiveBoxes.weeklyReports,
        HiveBoxes.financeTransactions,
        HiveBoxes.skillTracks,
        HiveBoxes.scheduleEvents,
        HiveBoxes.goalSettings,
        // หน้าหลักอ่านการตั้งค่าเพื่อเช็คว่าถึงเวลาเตือนสำรองข้อมูลหรือยัง
        HiveBoxes.appSettings,
      ])
        Hive.openBox<Map>(name, bytes: Uint8List(0)),
    ]);

    await MealRepository().put(MealEntry(
      id: 'm1',
      title: 'ข้าวกล้องอกไก่',
      type: MealType.lunch,
      time: '12:15',
      date: DateTime.now(),
      calories: 610,
      proteinGrams: 42,
    ));
    await WaterRepository().addGlass();
    await WaterRepository().addGlass();
  });

  tearDown(() async {
    await Hive.close();
    await tearDownTestHive();
  });

  testWidgets('การ์ดโภชนาการบนหน้าหลักแสดงพลังงานและน้ำของวันนี้', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DashboardScreen())));
    await tester.pump();

    final card = find.text('ทานอาหาร & โภชนาการ');
    // ระบุ ListView ชั้นนอกให้ชัด เพราะกริดการ์ดโมดูลก็เป็น Scrollable เหมือนกัน
    await tester.scrollUntilVisible(card, 250, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(card, findsOneWidget);
    // เป้าเริ่มต้น 2,000 kcal และ 2,000 มล. = 8 แก้ว
    expect(find.text('610 / 2000 kcal • น้ำ 2/8 แก้ว'), findsOneWidget);
  });
}
