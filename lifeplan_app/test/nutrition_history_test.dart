import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/nutrition_history.dart';
import 'package:lifeplan_app/data/repositories/meal_repository.dart';
import 'package:lifeplan_app/data/repositories/water_repository.dart';
import 'package:lifeplan_app/models/meal_entry.dart';
import 'package:lifeplan_app/models/water_log.dart';
import 'package:lifeplan_app/screens/nutrition_screen.dart';

/// การ์ด "ย้อนหลัง 7 วัน" ของหน้าโภชนาการ — ค่าเฉลี่ยต้องไม่ถูกถ่วงด้วยวันที่ยังไม่ได้บันทึก
void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  Future<void> logMeal(DateTime day, int calories) => MealRepository().put(MealEntry(
        id: 'm-${day.day}-$calories',
        title: 'มื้อ ${day.day}',
        type: MealType.lunch,
        time: '12:00',
        date: day,
        calories: calories,
      ));

  setUp(() async {
    await setUpTestHive();
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.mealEntries, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.waterLogs, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.exerciseItems, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
    ]);
  });

  tearDown(() async {
    await Hive.close();
    await tearDownTestHive();
  });

  test('เรียง 7 วันจากเก่าไปใหม่ วันนี้อยู่ท้ายสุด', () async {
    await logMeal(today, 500);
    final history = NutritionHistory.of(MealRepository(), WaterRepository(), today: today);

    expect(history.days, hasLength(7));
    expect(history.days.first.date, daysAgo(6));
    expect(history.days.last.date, DateTime(today.year, today.month, today.day));
    expect(history.days.last.totals.calories, 500);
  });

  test('เฉลี่ยนับเฉพาะวันที่บันทึกไว้ ไม่รวมวันที่ยังไม่ได้ใช้แอป', () async {
    await logMeal(today, 2000);
    await logMeal(daysAgo(1), 1000);
    final history = NutritionHistory.of(MealRepository(), WaterRepository(), today: today);

    expect(history.loggedDays, hasLength(2));
    expect(history.averageCalories, 1500); // ไม่ใช่ 3000/7
    expect(history.maxCalories, 2000);
  });

  test('วันที่ดื่มน้ำอย่างเดียวก็นับเป็นวันที่บันทึกแล้ว', () async {
    await WaterRepository().addMilliliters(WaterLog.glassMl * 3, day: daysAgo(2));
    final history = NutritionHistory.of(MealRepository(), WaterRepository(), today: today);

    final day = history.days[4];
    expect(day.isEmpty, isFalse);
    expect(day.glasses, 3);
    expect(history.averageWaterGlasses, 3);
    expect(history.averageCalories, 0);
  });

  test('นับวันที่ไม่เกินเป้าพลังงานเฉพาะวันที่บันทึก', () async {
    await logMeal(today, 2500);
    await logMeal(daysAgo(1), 1800);
    final history = NutritionHistory.of(MealRepository(), WaterRepository(), today: today);

    expect(history.daysWithinCalorieTarget(2000), 1);
    expect(history.daysWithinCalorieTarget(3000), 2);
  });

  testWidgets('หน้าจอแสดงการ์ดย้อนหลัง พร้อมค่าเฉลี่ยและจำนวนวันที่ไม่เกินเป้า', (tester) async {
    await logMeal(today, 2500);
    await logMeal(daysAgo(1), 1500);

    await tester.pumpWidget(const MaterialApp(home: NutritionScreen()));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('ย้อนหลัง 7 วัน'), 250);
    await tester.pumpAndSettle();

    expect(find.text('เฉลี่ย 2,000 kcal/วัน'), findsOneWidget);
    // เป้าเริ่มต้น 2,000 kcal → วันที่ 2,500 เกินเป้า เหลือ 1 ใน 2 วันที่ผ่าน
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('วันที่ไม่เกินเป้าพลังงาน'), findsOneWidget);
  });

  testWidgets('ยังไม่มีบันทึกย้อนหลังต้องขึ้นข้อความชวนให้เริ่มบันทึก', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NutritionScreen()));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('ย้อนหลัง 7 วัน'), 250);
    await tester.pumpAndSettle();
    expect(find.textContaining('ยังไม่มีบันทึกย้อนหลัง'), findsOneWidget);
  });
}
