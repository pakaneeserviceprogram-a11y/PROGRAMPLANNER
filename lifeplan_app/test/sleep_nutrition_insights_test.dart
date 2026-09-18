import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/meal_repository.dart';
import 'package:lifeplan_app/data/repositories/sleep_repository.dart';
import 'package:lifeplan_app/data/sleep_nutrition_insights.dart';
import 'package:lifeplan_app/models/meal_entry.dart';
import 'package:lifeplan_app/models/sleep_entry.dart';
import 'package:lifeplan_app/screens/sleep_screen.dart';

/// จับคู่คุณภาพการนอนกับคาเฟอีน/มื้อดึกจากบันทึกโภชนาการ
void main() {
  MealEntry meal(String title, String time, DateTime day) => MealEntry(
        id: '$title-$time-${day.day}',
        title: title,
        type: MealType.snack,
        time: time,
        date: day,
        calories: 100,
      );

  group('การจับคำ', () {
    final day = DateTime(2026, 9, 10);

    test('รู้จักเมนูคาเฟอีนทั้งไทยและอังกฤษ ไม่สนตัวพิมพ์', () {
      expect(SleepNutritionInsights.isCaffeine(meal('กาแฟดำ', '08:00', day)), isTrue);
      expect(SleepNutritionInsights.isCaffeine(meal('Iced LATTE', '08:00', day)), isTrue);
      expect(SleepNutritionInsights.isCaffeine(meal('ชาเขียวเย็น', '08:00', day)), isTrue);
      expect(SleepNutritionInsights.isCaffeine(meal('ข้าวผัดกุ้ง', '08:00', day)), isFalse);
    });

    test('คาเฟอีนนับเฉพาะตั้งแต่บ่าย 2 และมื้อดึกนับตั้งแต่ 2 ทุ่ม', () {
      expect(SleepNutritionInsights.isAfternoonCaffeine(meal('กาแฟ', '13:59', day)), isFalse);
      expect(SleepNutritionInsights.isAfternoonCaffeine(meal('กาแฟ', '14:00', day)), isTrue);
      expect(SleepNutritionInsights.isAfternoonCaffeine(meal('ข้าวมันไก่', '15:00', day)), isFalse);

      expect(SleepNutritionInsights.isLateMeal(meal('ข้าวต้ม', '19:59', day)), isFalse);
      expect(SleepNutritionInsights.isLateMeal(meal('ข้าวต้ม', '20:00', day)), isTrue);
    });
  });

  group('เทียบคะแนนการนอน', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.mealEntries, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.sleepEntries, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    /// เข้านอนคืนวันที่ [nightDay] แล้วตื่นวันถัดไป
    SleepEntry night(DateTime nightDay, {required String wake, int awakenings = 0}) => SleepEntry(
          date: DateTime(nightDay.year, nightDay.month, nightDay.day + 1),
          bedTime: '23:00',
          wakeTime: wake,
          awakenings: awakenings,
        );

    test('คืนที่ดื่มกาแฟบ่ายนอนแย่กว่า — ต้องเห็นส่วนต่าง', () async {
      final meals = MealRepository();
      final nights = <SleepEntry>[];

      // สองคืนที่ดื่มกาแฟบ่าย (นอนสั้น + ตื่นกลางดึก)
      for (final d in [DateTime(2026, 9, 1), DateTime(2026, 9, 2)]) {
        await meals.put(meal('กาแฟเย็น', '15:00', d));
        nights.add(night(d, wake: '04:00', awakenings: 2));
      }
      // สองคืนที่กินแต่ข้าว (นอนเต็มอิ่ม)
      for (final d in [DateTime(2026, 9, 3), DateTime(2026, 9, 4)]) {
        await meals.put(meal('ข้าวผัด', '12:00', d));
        nights.add(night(d, wake: '07:00'));
      }

      final caffeine = SleepNutritionInsights.compare(nights, meals, sleepTargetMinutes: 480).first;
      expect(caffeine.label, 'คาเฟอีนหลังบ่าย 2');
      expect(caffeine.withCount, 2);
      expect(caffeine.withoutCount, 2);
      expect(caffeine.delta, greaterThan(5));
      expect(caffeine.isMeaningful, isTrue);
    });

    test('ข้อมูลข้างเดียวหรือน้อยเกินไป ยังสรุปไม่ได้', () async {
      final meals = MealRepository();
      final day = DateTime(2026, 9, 1);
      await meals.put(meal('กาแฟ', '15:00', day));

      final result = SleepNutritionInsights.compare([night(day, wake: '05:00')], meals, sleepTargetMinutes: 480).first;
      expect(result.withCount, 1);
      expect(result.withoutCount, 0);
      expect(result.hasEnoughData, isFalse);
      expect(result.isMeaningful, isFalse);
    });

    test('คืนที่ไม่ได้บันทึกมื้ออาหารเลยถูกข้าม ไม่นับว่า "ไม่ได้กิน"', () async {
      final meals = MealRepository();
      final withMealDay = DateTime(2026, 9, 1);
      await meals.put(meal('กาแฟ', '15:00', withMealDay));

      final result = SleepNutritionInsights.compare(
        [night(withMealDay, wake: '05:00'), night(DateTime(2026, 9, 5), wake: '07:00')],
        meals,
        sleepTargetMinutes: 480,
      ).first;

      expect(result.withCount, 1);
      expect(result.withoutCount, 0); // คืนที่ไม่มีบันทึกมื้อไม่ถูกนับเข้ากลุ่มไหนเลย
    });

    testWidgets('หน้าจอบอกว่ายังเทียบไม่ได้เมื่อข้อมูลไม่พอ', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SleepScreen()));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('การนอนกับสิ่งที่กิน'), 250);
      await tester.pumpAndSettle();
      expect(find.textContaining('ยังเทียบไม่ได้'), findsOneWidget);
    });

    testWidgets('มีข้อมูลพอแล้วโชว์ส่วนต่างพร้อมคำแนะนำ', (tester) async {
      final meals = MealRepository();
      final sleep = SleepRepository();
      final now = DateTime.now();

      // 4 คืนล่าสุด: สองคืนแรกดื่มกาแฟบ่ายแล้วนอนแย่ สองคืนหลังไม่ได้ดื่มและนอนเต็มอิ่ม
      for (var i = 1; i <= 4; i++) {
        final nightDay = DateTime(now.year, now.month, now.day - i);
        final drinksCoffee = i <= 2;
        await meals.put(meal(drinksCoffee ? 'กาแฟเย็น' : 'ข้าวผัด', drinksCoffee ? '15:00' : '12:00', nightDay));
        await sleep.put(SleepEntry(
          date: DateTime(nightDay.year, nightDay.month, nightDay.day + 1),
          bedTime: '23:00',
          wakeTime: drinksCoffee ? '04:00' : '07:00',
          awakenings: drinksCoffee ? 2 : 0,
        ));
      }

      await tester.pumpWidget(const MaterialApp(home: SleepScreen()));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('การนอนกับสิ่งที่กิน'), 250);
      await tester.pumpAndSettle();

      expect(find.text('คาเฟอีนหลังบ่าย 2'), findsOneWidget);
      expect(find.textContaining('คืนที่กิน'), findsWidgets);
      expect(find.textContaining('ลองเลื่อนกาแฟ'), findsOneWidget);
    });
  });
}
