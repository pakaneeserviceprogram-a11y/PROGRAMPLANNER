import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/meal_repository.dart';
import 'package:lifeplan_app/data/repositories/water_repository.dart';
import 'package:lifeplan_app/models/meal_entry.dart';
import 'package:lifeplan_app/models/water_log.dart';
import 'package:lifeplan_app/screens/nutrition_screen.dart';

/// box แบบ in-memory (bytes:) เหมือน schedule_screen_test — การเขียนไม่แตะไฟล์จริง
/// จึงจบได้ภายใน FakeAsync ของ testWidgets
void main() {
  setUp(() async {
    await setUpTestHive();
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.mealEntries, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.waterLogs, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.exerciseItems, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
      // การ์ดเตือนมื้ออาหาร/ดื่มน้ำอ่านการตั้งค่าแอป
      Hive.openBox<Map>(HiveBoxes.appSettings, bytes: Uint8List(0)),
    ]);

    await MealRepository().put(MealEntry(
      id: 'm1',
      title: 'ข้าวกล้องอกไก่',
      type: MealType.lunch,
      time: '12:15',
      date: DateTime.now(),
      calories: 610,
      proteinGrams: 42,
      carbGrams: 70,
      fatGrams: 14,
      sugarGrams: 6,
      vitamins: const [Vitamin.a, Vitamin.c],
      workoutTiming: WorkoutTiming.postWorkout,
    ));
  });

  tearDown(() async {
    await Hive.close();
    await tearDownTestHive();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: NutritionScreen()));
    await tester.pump();
  }

  testWidgets('แสดงมื้ออาหารของวันนี้พร้อมสารอาหารที่บันทึกไว้', (tester) async {
    await pumpScreen(tester);

    // 610 kcal จากมื้อเดียว เทียบเป้าหมายเริ่มต้น 2,000 kcal
    expect(find.text('610 / 2,000 kcal'), findsOneWidget);

    // รายการมื้ออาหารอยู่ล่างจอ ต้องเลื่อนลงไปก่อนถึงจะถูกสร้าง
    await tester.scrollUntilVisible(find.text('ข้าวกล้องอกไก่'), 250);
    await tester.pumpAndSettle();

    expect(find.text('12:15'), findsOneWidget);
    // ป้าย "หลังออก" ในแถวมื้ออาหาร (ข้อความเต็ม ไม่ใช่หัวข้อ "มื้อหลังออกกำลังกาย")
    expect(find.text('หลังออก'), findsOneWidget);
    expect(find.textContaining('โปรตีน 42 ก.'), findsOneWidget);
  });

  testWidgets('กดเพิ่มน้ำหนึ่งแก้วแล้วบันทึกลง Hive และอัปเดตหน้าจอ', (tester) async {
    await pumpScreen(tester);
    expect(find.textContaining('0 แก้ว'), findsOneWidget);

    // ปุ่มบวกของการ์ดน้ำอยู่ก่อนปุ่ม "บันทึกมื้ออาหาร" ในลำดับต้นไม้
    final addWater = find.byIcon(Icons.add_rounded).first;
    await tester.ensureVisible(addWater);
    await tester.pumpAndSettle();
    await tester.tap(addWater);
    await tester.pumpAndSettle();

    expect(WaterRepository().getToday().milliliters, WaterLog.glassMl);
    expect(find.textContaining('1 แก้ว'), findsOneWidget);
  });

  testWidgets('ยังไม่บันทึกมื้อไหนเลย ต้องขึ้นข้อความว่าง', (tester) async {
    await MealRepository().delete('m1');
    await pumpScreen(tester);

    expect(find.text('0 / 2,000 kcal'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('ยังไม่ได้บันทึกมื้ออาหารของวันนี้'), 250);
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่ได้บันทึกมื้ออาหารของวันนี้'), findsOneWidget);
  });
}
