import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/meal_reminder.dart';
import 'package:lifeplan_app/data/notifications.dart';
import 'package:lifeplan_app/data/repositories/app_settings_repository.dart';
import 'package:lifeplan_app/data/repositories/schedule_repository.dart';
import 'package:lifeplan_app/models/app_settings.dart';
import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';
import 'package:lifeplan_app/screens/nutrition_screen.dart';

/// เตือนมื้ออาหาร (เป็นกิจกรรมในตารางเวลา) และเตือนดื่มน้ำ (แจ้งเตือนรายวันตรง ๆ)
void main() {
  group('เตือนมื้ออาหาร', () {
    setUp(() async {
      await setUpTestHive();
      await Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0));
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    test('เปิดมื้อเช้าแล้วได้กิจกรรมครบ 7 วันในชุดเดียว หมวดโภชนาการ', () async {
      final repo = ScheduleRepository();
      await MealReminder.apply(repo, MealSlot.breakfast, MealSlot.breakfast.defaultTime);

      final events = repo.getAll();
      expect(events, hasLength(7));
      expect(events.map((e) => e.weekday).toSet(), {1, 2, 3, 4, 5, 6, 7});
      expect(events.every((e) => e.time == '07:30'), isTrue);
      expect(events.every((e) => e.title == 'มื้อเช้า'), isTrue);
      expect(events.every((e) => e.category == LifeCategory.nutrition), isTrue);
      expect(events.map((e) => e.seriesKey).toSet(), {MealReminder.seriesIdOf(MealSlot.breakfast)});
      expect(MealReminder.timeOf(repo, MealSlot.breakfast), '07:30');
    });

    test('แต่ละมื้อแยกกัน เปิด/ปิดทีละมื้อได้', () async {
      final repo = ScheduleRepository();
      await MealReminder.apply(repo, MealSlot.lunch, '12:00');
      await MealReminder.apply(repo, MealSlot.dinner, '18:30');
      expect(repo.getAll(), hasLength(14));

      await MealReminder.remove(repo, MealSlot.lunch);
      expect(MealReminder.isOn(repo, MealSlot.lunch), isFalse);
      expect(MealReminder.isOn(repo, MealSlot.dinner), isTrue);
      expect(repo.getAll(), hasLength(7));
    });

    test('แก้เวลาแล้วไม่สร้างรายการซ้ำ และไม่ยุ่งกับกิจกรรมอื่น', () async {
      final repo = ScheduleRepository();
      await repo.put(const ScheduleEvent(
        id: 'run',
        time: '06:00',
        weekday: DateTime.monday,
        title: 'วิ่งตอนเช้า',
        category: LifeCategory.exercise,
      ));
      await MealReminder.apply(repo, MealSlot.breakfast, '07:30');
      await MealReminder.apply(repo, MealSlot.breakfast, '08:15');

      expect(repo.getAll(), hasLength(8));
      expect(MealReminder.timeOf(repo, MealSlot.breakfast), '08:15');

      await MealReminder.remove(repo, MealSlot.breakfast);
      expect(repo.getAll().single.title, 'วิ่งตอนเช้า');
    });
  });

  group('เตือนดื่มน้ำ', () {
    test('ไล่เวลาตามช่วงและระยะห่างที่ตั้งไว้', () {
      const settings = AppSettings(waterRemindersEnabled: true, waterIntervalHours: 2, waterStartHour: 9, waterEndHour: 20);
      expect(settings.waterReminderTimes, ['09:00', '11:00', '13:00', '15:00', '17:00', '19:00']);

      // ทุก 3 ชม. ลงตัวพอดีที่ปลายช่วง
      expect(
        const AppSettings(waterRemindersEnabled: true, waterIntervalHours: 3, waterStartHour: 9, waterEndHour: 18).waterReminderTimes,
        ['09:00', '12:00', '15:00', '18:00'],
      );
    });

    test('ปิดอยู่หรือค่าไม่สมเหตุสมผล = ไม่มีเวลาเตือน', () {
      expect(const AppSettings().waterReminderTimes, isEmpty);
      expect(const AppSettings(waterRemindersEnabled: true, waterIntervalHours: 0).waterReminderTimes, isEmpty);
      expect(
        const AppSettings(waterRemindersEnabled: true, waterStartHour: 20, waterEndHour: 9).waterReminderTimes,
        isEmpty,
      );
    });

    test('ค่าที่บันทึกไว้ก่อนมีฟีเจอร์นี้อ่านได้ และค่าใหม่บันทึกกลับได้ครบ', () {
      final legacy = AppSettings.fromMap({'scheduleRemindersEnabled': true});
      expect(legacy.waterRemindersEnabled, isFalse);
      expect(legacy.waterIntervalHours, 2);

      const settings = AppSettings(waterRemindersEnabled: true, waterIntervalHours: 4, waterStartHour: 8, waterEndHour: 21);
      final back = AppSettings.fromMap(Map<String, dynamic>.from(settings.toMap()));
      expect(back.waterRemindersEnabled, isTrue);
      expect(back.waterIntervalHours, 4);
      expect(back.waterStartHour, 8);
      expect(back.waterEndHour, 21);
    });

    test('เวลาถัดไปของการเตือนรายวัน: วันนี้ถ้ายังไม่ถึง ไม่งั้นพรุ่งนี้', () {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));

      final morning = tz.TZDateTime(tz.local, 2026, 9, 18, 8);
      expect(NotificationService.nextDailyOccurrence('09:00', now: morning), tz.TZDateTime(tz.local, 2026, 9, 18, 9));

      final evening = tz.TZDateTime(tz.local, 2026, 9, 18, 21);
      expect(NotificationService.nextDailyOccurrence('09:00', now: evening), tz.TZDateTime(tz.local, 2026, 9, 19, 9));
    });
  });

  group('หน้าโภชนาการ', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.mealEntries, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.waterLogs, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.exerciseItems, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.appSettings, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    Future<void> openCard(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: NutritionScreen()));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('เตือนมื้ออาหาร & ดื่มน้ำ'), 250);
      await tester.pumpAndSettle();
    }

    testWidgets('เปิดเตือนมื้อเช้าแล้วเขียนลงตารางเวลาจริง', (tester) async {
      await openCard(tester);
      expect(find.text('มื้อเช้า'), findsOneWidget);

      final row = find.ancestor(of: find.text('มื้อเช้า'), matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(MealReminder.timeOf(ScheduleRepository(), MealSlot.breakfast), '07:30');
      expect(find.text('07:30'), findsOneWidget);
    });

    testWidgets('เปิดเตือนดื่มน้ำแล้วบันทึกลงการตั้งค่า พร้อมบอกจำนวนครั้งต่อวัน', (tester) async {
      await openCard(tester);

      final row = find.ancestor(of: find.text('ดื่มน้ำ'), matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(AppSettingsRepository().get().waterRemindersEnabled, isTrue);
      expect(find.text('09:00–19:00 น. • 6 ครั้ง/วัน'), findsOneWidget);
      expect(find.text('ทุก 2 ชั่วโมง'), findsOneWidget);
    });
  });
}
