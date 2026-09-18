import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/bedtime_reminder.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/schedule_repository.dart';
import 'package:lifeplan_app/data/repositories/sleep_repository.dart';
import 'package:lifeplan_app/models/goal_settings.dart';
import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';
import 'package:lifeplan_app/models/sleep_entry.dart';
import 'package:lifeplan_app/screens/sleep_screen.dart';

/// เตือน "ถึงเวลาเข้านอน" อัตโนมัติ — คำนวณจากเวลาตื่นเฉลี่ยจริงลบเป้าเวลานอน
void main() {
  const goals = GoalSettings(sleepTargetMinutes: 480); // 8 ชม.

  SleepEntry night(DateTime date, String bed, String wake) =>
      SleepEntry(date: date, bedTime: bed, wakeTime: wake);

  group('การคำนวณเวลา', () {
    test('เวลาตื่นเฉลี่ยลบเป้า 8 ชม. ได้เวลาเข้านอน', () {
      final nights = [
        night(DateTime(2026, 9, 16), '23:00', '06:00'),
        night(DateTime(2026, 9, 17), '23:30', '07:00'),
      ];
      // ตื่นเฉลี่ย 06:30 − 8 ชม. = 22:30
      expect(BedtimeReminder.suggestedTime(nights, goals), '22:30');
    });

    test('ข้ามเที่ยงคืนได้ เข้านอนตกไปเป็นคืนก่อนหน้า', () {
      final nights = [night(DateTime(2026, 9, 17), '02:00', '07:30')];
      expect(BedtimeReminder.suggestedTime(nights, const GoalSettings(sleepTargetMinutes: 600)), '21:30');

      // ตื่น 05:00 กับเป้า 8 ชม. → เข้านอน 21:00 ของวันก่อน
      final early = [night(DateTime(2026, 9, 17), '21:00', '05:00')];
      expect(BedtimeReminder.suggestedTime(early, goals), '21:00');
    });

    test('ตื่นดึกมาก (01:00) ต้องไม่ดึงค่าเฉลี่ยไปกลางดึก', () {
      final nights = [
        night(DateTime(2026, 9, 16), '17:00', '01:00'),
        night(DateTime(2026, 9, 17), '23:00', '07:00'),
      ];
      // 01:00 นับเป็น 25:00 → เฉลี่ยกับ 07:00 ได้ 16:00 ไม่ใช่ 04:00
      expect(BedtimeReminder.averageWakeMinutes(nights), 16 * 60);
    });

    test('ยังไม่มีบันทึกการนอน = ยังคำนวณไม่ได้', () {
      expect(BedtimeReminder.suggestedTime(const [], goals), isNull);
      expect(BedtimeReminder.averageWakeMinutes(const []), isNull);
    });
  });

  group('เขียนลงตารางเวลา', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.sleepEntries, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    test('เปิดแล้วได้กิจกรรมครบ 7 วันในชุดเดียว หมวดการนอน', () async {
      final repo = ScheduleRepository();
      await BedtimeReminder.apply(repo, '22:30');

      final events = repo.getAll();
      expect(events, hasLength(7));
      expect(events.map((e) => e.weekday).toSet(), {1, 2, 3, 4, 5, 6, 7});
      expect(events.every((e) => e.time == '22:30'), isTrue);
      expect(events.every((e) => e.category == LifeCategory.sleep), isTrue);
      expect(events.map((e) => e.seriesKey).toSet(), {BedtimeReminder.seriesId});
      expect(BedtimeReminder.isOn(repo), isTrue);
      expect(BedtimeReminder.currentTime(repo), '22:30');
    });

    test('ปรับเวลาแล้วไม่สร้างรายการซ้ำ และปิดแล้วลบครบ', () async {
      final repo = ScheduleRepository();
      await BedtimeReminder.apply(repo, '22:30');
      await BedtimeReminder.apply(repo, '23:00');

      expect(repo.getAll(), hasLength(7));
      expect(BedtimeReminder.currentTime(repo), '23:00');

      await BedtimeReminder.remove(repo);
      expect(repo.getAll(), isEmpty);
      expect(BedtimeReminder.isOn(repo), isFalse);
    });

    test('ไม่ยุ่งกับกิจกรรมอื่นในตาราง', () async {
      final repo = ScheduleRepository();
      await repo.put(const ScheduleEvent(
        id: 'run',
        time: '06:00',
        weekday: DateTime.monday,
        title: 'วิ่งตอนเช้า',
        category: LifeCategory.exercise,
      ));
      await BedtimeReminder.apply(repo, '22:30');
      await BedtimeReminder.remove(repo);

      expect(repo.getAll().single.title, 'วิ่งตอนเช้า');
    });

    testWidgets('หน้าการนอน: เปิดสวิตช์แล้วเขียนลงตารางเวลาจริง', (tester) async {
      await SleepRepository().put(night(DateTime.now(), '23:00', '06:30'));

      await tester.pumpWidget(const MaterialApp(home: SleepScreen()));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('เตือนให้เข้านอน'), 200);
      await tester.pumpAndSettle();
      expect(find.textContaining('แนะนำ 22:30 น.'), findsOneWidget);

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(ScheduleRepository().getAll(), hasLength(7));
      expect(find.textContaining('เตือนทุกวัน 22:30 น.'), findsOneWidget);
    });

    testWidgets('ยังไม่มีบันทึกการนอน สวิตช์กดไม่ได้และบอกเหตุผล', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SleepScreen()));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('เตือนให้เข้านอน'), 200);
      await tester.pumpAndSettle();

      expect(find.textContaining('บันทึกการนอนสักคืนก่อน'), findsOneWidget);
      final switchWidget = tester.widgetList<Switch>(find.byType(Switch)).last;
      expect(switchWidget.onChanged, isNull);
    });
  });
}
