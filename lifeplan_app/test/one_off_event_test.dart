import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:lifeplan_app/data/calendar_utils.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/notifications.dart';
import 'package:lifeplan_app/data/reminder_watcher.dart';
import 'package:lifeplan_app/data/repositories/schedule_repository.dart';
import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';
import 'package:lifeplan_app/screens/schedule_screen.dart';

/// นัดหมายเฉพาะวันที่ (ScheduleEvent.date) — ต้องขึ้นเฉพาะวันนั้น เตือนครั้งเดียว
/// และไม่ปนกับฟีเจอร์ของตารางประจำสัปดาห์ (คัดลอก/ชุดกิจกรรม)
void main() {
  // 2026-09-25 เป็นวันศุกร์
  final appointmentDay = DateTime(2026, 9, 25);
  final dentist = ScheduleEvent.oneOff(
    id: 'dentist',
    time: '10:30',
    date: appointmentDay,
    title: 'นัดทำฟัน',
    category: LifeCategory.crm,
  );
  const weeklyFriday = ScheduleEvent(id: 'fri', time: '08:00', weekday: DateTime.friday, title: 'ประชุมวันศุกร์', category: LifeCategory.work);

  group('ScheduleEvent', () {
    test('oneOff ตั้ง weekday ตามวันที่ และตัดเวลาทิ้ง', () {
      final e = ScheduleEvent.oneOff(id: 'x', time: '09:00', date: DateTime(2026, 9, 25, 17, 45), title: 't', category: LifeCategory.work);
      expect(e.weekday, DateTime.friday);
      expect(e.date, DateTime(2026, 9, 25));
      expect(e.isOneOff, isTrue);
    });

    test('occursOn: เฉพาะวันที่ขึ้นวันเดียว ประจำสัปดาห์ขึ้นทุกสัปดาห์', () {
      expect(dentist.occursOn(DateTime(2026, 9, 25)), isTrue);
      expect(dentist.occursOn(DateTime(2026, 10, 2)), isFalse); // ศุกร์ถัดไป
      expect(weeklyFriday.occursOn(DateTime(2026, 9, 25)), isTrue);
      expect(weeklyFriday.occursOn(DateTime(2026, 10, 2)), isTrue);
    });

    test('toMap/fromMap เก็บวันที่ครบ และเรคคอร์ดเก่าที่ไม่มี date ยังเป็นประจำสัปดาห์', () {
      final map = dentist.toMap();
      expect(map['date'], '2026-09-25');
      final back = ScheduleEvent.fromMap(Map<String, dynamic>.from(map));
      expect(back.date, DateTime(2026, 9, 25));
      expect(back.weekday, DateTime.friday);

      final legacy = ScheduleEvent.fromMap({'id': 'old', 'time': '07:00', 'weekday': 3, 'title': 'เก่า', 'category': 'work'});
      expect(legacy.isOneOff, isFalse);
      expect(legacy.weekday, 3);
    });

    test('fromMap ยึด weekday จากวันที่ ถ้าข้อมูลไม่ตรงกัน', () {
      final e = ScheduleEvent.fromMap({'id': 'x', 'time': '07:00', 'weekday': 1, 'date': '2026-09-25', 'title': 't', 'category': 'work'});
      expect(e.weekday, DateTime.friday);
    });
  });

  group('ScheduleRepository', () {
    setUp(() async {
      await setUpTestHive();
      await Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0));
      final repo = ScheduleRepository();
      await repo.put(dentist);
      await repo.put(weeklyFriday);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    test('getForDate รวมนัดเฉพาะวันเข้ากับกิจกรรมประจำ เรียงตามเวลา', () {
      final repo = ScheduleRepository();
      expect(repo.getForDate(DateTime(2026, 9, 25)).map((e) => e.id), ['fri', 'dentist']);
      expect(repo.getForDate(DateTime(2026, 10, 2)).map((e) => e.id), ['fri']);
    });

    test('getByWeekday/getWeek เป็นตารางประจำสัปดาห์ล้วน ไม่มีนัดเฉพาะวัน', () {
      final repo = ScheduleRepository();
      expect(repo.getByWeekday(DateTime.friday).map((e) => e.id), ['fri']);
      expect(repo.getWeek()[DateTime.friday - 1].map((e) => e.id), ['fri']);
    });

    test('นัดเฉพาะวันไม่มีชุด และคัดลอกไปวันอื่นแบบรายสัปดาห์ไม่ได้', () async {
      final repo = ScheduleRepository();
      expect(repo.seriesOf(dentist).map((e) => e.id), ['dentist']);
      expect(await repo.copyToWeekdays(dentist, [1, 2, 3]), 0);
      expect(repo.getAll(), hasLength(2));
    });

    test('copyDay คัดลอกเฉพาะกิจกรรมประจำของวันนั้น', () async {
      final repo = ScheduleRepository();
      expect(await repo.copyDay(DateTime.friday, [DateTime.monday]), 1);
      expect(repo.getByWeekday(DateTime.monday).single.title, 'ประชุมวันศุกร์');
    });
  });

  group('เวลาเตือน', () {
    setUpAll(() {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));
    });

    test('แจ้งเตือนของระบบ: ตั้งครั้งเดียวตรงวันนัด และไม่ตั้งถ้าเลยไปแล้ว', () {
      final before = tz.TZDateTime(tz.local, 2026, 9, 20, 12);
      expect(NotificationService.nextOccurrenceOf(dentist, 15, now: before), tz.TZDateTime(tz.local, 2026, 9, 25, 10, 15));

      final after = tz.TZDateTime(tz.local, 2026, 9, 25, 10, 16);
      expect(NotificationService.nextOccurrenceOf(dentist, 15, now: after), isNull);
    });

    test('ป๊อปอัปในแอป: ยังไม่ถึงวันนัดไม่ย้อนไปหารอบสัปดาห์ก่อน', () {
      expect(ReminderWatcher.lastRemindAtOrBefore(dentist, 15, DateTime(2026, 9, 25, 9)), isNull);
      expect(ReminderWatcher.lastRemindAtOrBefore(dentist, 15, DateTime(2026, 9, 25, 10, 20)), DateTime(2026, 9, 25, 10, 15));
      // ศุกร์ถัดไปไม่มีรอบใหม่ — รอบล่าสุดยังเป็นวันนัดเดิม ป๊อปอัปจึงไม่เด้งซ้ำ
      expect(ReminderWatcher.lastRemindAtOrBefore(dentist, 15, DateTime(2026, 10, 2, 11)), DateTime(2026, 9, 25, 10, 15));
    });
  });

  group('หน้าตารางเวลา', () {
    setUp(() async {
      await setUpTestHive();
      await Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0));
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ScheduleScreen())));
      await tester.pump();
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('เพิ่มนัดเฉพาะวันที่ ขึ้นแค่วันนั้น ไม่ขึ้นสัปดาห์ถัดไป', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      // มุมมองวัน ค่าเริ่มต้นคือทุกสัปดาห์ — สลับเป็นเฉพาะวันที่ (วันที่ = วันที่เลือกอยู่ = วันนี้)
      await tester.enterText(find.byType(TextField).first, 'นัดหมอ');
      await tapVisible(tester, find.byKey(const ValueKey('repeat-one-off')));
      expect(find.byKey(const ValueKey('event-date-field')), findsOneWidget);
      // ฟีเจอร์ของตารางประจำ (เลือกหลายวัน) ต้องหายไป
      expect(find.text('ทุกวัน'), findsNothing);
      await tapVisible(tester, find.text('บันทึก'));

      final today = CalendarUtils.dateOnly(DateTime.now());
      final saved = ScheduleRepository().getAll().single;
      expect(saved.date, today);
      expect(saved.weekday, today.weekday);
      expect(find.text('นัดหมอ'), findsOneWidget);
      expect(find.text('นัดหมายเฉพาะวันนี้'), findsOneWidget);

      // เลื่อนไปสัปดาห์หน้า แล้วเลือกวันเดียวกัน — ต้องว่าง
      await tester.tap(find.byTooltip('ถัดไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CalendarUtils.weekdayShort[today.weekday - 1]));
      await tester.pumpAndSettle();
      expect(find.text('นัดหมอ'), findsNothing);
    });

    testWidgets('เพิ่มจากมุมมองเดือน ค่าเริ่มต้นเป็นนัดเฉพาะวันที่ที่แตะในปฏิทิน', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('เดือน'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      // วันที่ 20 ของเดือนนี้ — มีในทุกเดือนและไม่ชนกับวันนี้เสมอไป
      final target = DateTime(now.year, now.month, 20);
      final cell = find.byKey(ValueKey('month-cell-${target.year}-${target.month}-${target.day}'));
      await tester.ensureVisible(cell);
      await tester.pumpAndSettle();
      await tester.tap(cell);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('event-date-field')), findsOneWidget);
      // หัวข้อใต้ปฏิทินด้านหลังฟอร์มก็มีข้อความเดียวกัน — ดูเฉพาะในช่องวันที่ของฟอร์ม
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('event-date-field')),
          matching: find.text('วัน${CalendarUtils.weekdayFull[target.weekday - 1]}ที่ ${CalendarUtils.thaiDate(target)}'),
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, 'ส่งเอกสารประกัน');
      await tapVisible(tester, find.text('บันทึก'));

      final saved = ScheduleRepository().getAll().single;
      expect(saved.date, target);
      expect(ScheduleRepository().getForDate(CalendarUtils.addDays(target, 7)), isEmpty);
    });

    testWidgets('แก้นัดเฉพาะวันให้เป็นกิจกรรมประจำสัปดาห์ได้', (tester) async {
      final today = CalendarUtils.dateOnly(DateTime.now());
      await ScheduleRepository().put(ScheduleEvent.oneOff(id: 'a', time: '09:00', date: today, title: 'โยคะ', category: LifeCategory.exercise));
      await pumpScreen(tester);

      await tester.tap(find.text('โยคะ'));
      await tester.pumpAndSettle();
      expect(find.text('แก้ไขกิจกรรม'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('repeat-weekly')));
      await tapVisible(tester, find.text('บันทึก'));

      final saved = ScheduleRepository().getAll().single;
      expect(saved.id, 'a');
      expect(saved.isOneOff, isFalse);
      expect(saved.weekday, today.weekday);
      expect(ScheduleRepository().getForDate(CalendarUtils.addDays(today, 7)).single.id, 'a');
    });
  });
}
