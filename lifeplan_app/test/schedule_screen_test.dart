import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/calendar_utils.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/schedule_repository.dart';
import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';
import 'package:lifeplan_app/screens/schedule_screen.dart';

/// box แบบ in-memory (bytes:) — การเขียนไม่แตะไฟล์จริง จึงจบได้ภายใน FakeAsync ของ
/// testWidgets ทำให้ทดสอบแก้ไข/ลบผ่านหน้าจอได้ (ดูปัญหา file I/O ใน widget_test.dart)
void main() {
  setUp(() async {
    await setUpTestHive();
    await Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0));

    final repo = ScheduleRepository();
    await repo.put(const ScheduleEvent(
        id: 'mon', time: '07:00', weekday: DateTime.monday, title: 'วิ่งเช้าวันจันทร์', category: LifeCategory.exercise));
    await repo.put(const ScheduleEvent(
        id: 'thu', time: '15:00', weekday: DateTime.thursday, title: 'นัดลูกค้าพฤหัส', category: LifeCategory.crm));
  });

  tearDown(() async {
    // box in-memory ลบจากดิสก์ไม่ได้ ต้องปิดก่อนให้ tearDownTestHive ลบแค่โฟลเดอร์ชั่วคราว
    await Hive.close();
    await tearDownTestHive();
  });

  Future<void> tapVisible(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    // ฟอร์มยาวเกินจอทดสอบ (800x600) และช่องข้อความที่เพิ่งพิมพ์จะเลื่อนตัวเองกลับมาให้เห็น
    // หลังเลื่อนครั้งแรก — ต้องเลื่อนซ้ำอีกรอบให้ปุ่มอยู่ในจอจริง
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ScheduleScreen())));
    await tester.pump();
  }

  testWidgets('มุมมองรายวันแสดงเฉพาะกิจกรรมของวันที่เลือก', (tester) async {
    await pumpScreen(tester);

    // แตะช่อง "จ" ในแถบ 7 วัน เพื่อเลือกวันจันทร์
    await tester.tap(find.text('จ'));
    await tester.pump();

    expect(find.text('วิ่งเช้าวันจันทร์'), findsOneWidget);
    expect(find.text('นัดลูกค้าพฤหัส'), findsNothing);

    await tester.tap(find.text('พฤ'));
    await tester.pump();

    expect(find.text('นัดลูกค้าพฤหัส'), findsOneWidget);
    expect(find.text('วิ่งเช้าวันจันทร์'), findsNothing);
  });

  testWidgets('มุมมองรายสัปดาห์แสดงครบ 7 วันพร้อมกัน', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('สัปดาห์'));
    await tester.pump();

    for (final day in ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์']) {
      expect(find.text(day), findsOneWidget, reason: 'ต้องมีคอลัมน์วัน$day');
    }

    // กิจกรรมของคนละวันต้องปรากฏพร้อมกันในตารางสัปดาห์
    expect(find.text('วิ่งเช้าวันจันทร์'), findsOneWidget);
    expect(find.text('นัดลูกค้าพฤหัส'), findsOneWidget);
    expect(find.text('ว่าง'), findsNWidgets(5));
  });

  testWidgets('แตะกิจกรรมเพื่อแก้ไข บันทึกทับรายการเดิมไม่สร้างใหม่', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('จ'));
    await tester.pump();

    await tester.tap(find.text('วิ่งเช้าวันจันทร์'));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขกิจกรรม'), findsOneWidget);
    expect(find.text('ลบกิจกรรมนี้'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'วิ่ง 5 กม.');
    await tapVisible(tester, 'บันทึก');

    final events = ScheduleRepository().getAll();
    expect(events, hasLength(2));
    final edited = events.singleWhere((e) => e.id == 'mon');
    expect(edited.title, 'วิ่ง 5 กม.');
    expect(edited.time, '07:00');
    expect(edited.category, LifeCategory.exercise);
    expect(find.text('วิ่ง 5 กม.'), findsOneWidget);
  });

  testWidgets('ลบจากฟอร์มแก้ไขต้องยืนยันก่อน กดยกเลิกแล้วข้อมูลยังอยู่', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('จ'));
    await tester.pump();

    await tester.tap(find.text('วิ่งเช้าวันจันทร์'));
    await tester.pumpAndSettle();

    await tapVisible(tester, 'ลบกิจกรรมนี้');
    expect(find.text('ลบกิจกรรม?'), findsOneWidget);

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(ScheduleRepository().getAll().any((e) => e.id == 'mon'), isTrue);

    await tapVisible(tester, 'ลบกิจกรรมนี้');
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();

    expect(ScheduleRepository().getAll().map((e) => e.id), ['thu']);
    expect(find.text('แก้ไขกิจกรรม'), findsNothing);
    expect(find.text('วิ่งเช้าวันจันทร์'), findsNothing);
  });

  testWidgets('แตะกิจกรรมในมุมมองรายสัปดาห์ก็เปิดฟอร์มแก้ไขได้', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('สัปดาห์'));
    await tester.pump();

    await tester.tap(find.text('นัดลูกค้าพฤหัส'));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขกิจกรรม'), findsOneWidget);
    expect(find.text('วันพฤหัสบดี'), findsOneWidget);
  });

  testWidgets('เพิ่มกิจกรรมใหม่แบบเลือกหลายวัน สร้างรายการแยกของแต่ละวันในชุดเดียวกัน', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'เข้านอน');
    await tapVisible(tester, 'ทุกวัน');
    await tapVisible(tester, 'บันทึก');

    final beds = ScheduleRepository().getAll().where((e) => e.title == 'เข้านอน').toList();
    expect(beds.map((e) => e.weekday).toSet(), {1, 2, 3, 4, 5, 6, 7});
    expect(beds.map((e) => e.id).toSet(), hasLength(7));
    expect(beds.map((e) => e.seriesKey).toSet(), hasLength(1));
    expect(beds.map((e) => e.time).toSet(), hasLength(1));
  });

  testWidgets('แก้ไขกิจกรรมแล้วคัดลอกไปวันอื่น จากนั้นแก้ทั้งชุดได้', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('จ'));
    await tester.pump();

    // คัดลอกวิ่งวันจันทร์ไปวันอังคารและพุธ
    await tester.tap(find.text('วิ่งเช้าวันจันทร์'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('weekday-chip-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('weekday-chip-2')));
    await tester.tap(find.byKey(const ValueKey('weekday-chip-3')));
    await tester.pump();
    await tapVisible(tester, 'บันทึก');

    final repo = ScheduleRepository();
    final runs = repo.getAll().where((e) => e.title == 'วิ่งเช้าวันจันทร์').toList();
    expect(runs.map((e) => e.weekday).toSet(), {1, 2, 3});

    // เปิดวันอังคาร แล้วแก้ชื่อทั้งชุด
    await tester.tap(find.text('อ'));
    await tester.pump();
    await tester.tap(find.text('วิ่งเช้าวันจันทร์'));
    await tester.pumpAndSettle();
    expect(find.text('ใช้การแก้ไขกับทุกวันในชุดนี้'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'วิ่ง 6 โมงเช้า');
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tapVisible(tester, 'บันทึก');

    final renamed = repo.getAll().where((e) => e.title == 'วิ่ง 6 โมงเช้า').toList();
    expect(renamed.map((e) => e.weekday).toSet(), {1, 2, 3});
    expect(repo.getAll().singleWhere((e) => e.id == 'thu').title, 'นัดลูกค้าพฤหัส');
  });

  testWidgets('ลบกิจกรรมที่มีหลายวัน เลือกลบทุกวันในชุดได้', (tester) async {
    final repo = ScheduleRepository();
    await repo.copyToWeekdays(repo.getAll().singleWhere((e) => e.id == 'mon'), [2, 3]);

    await pumpScreen(tester);
    await tester.tap(find.text('อ'));
    await tester.pump();
    await tester.tap(find.text('วิ่งเช้าวันจันทร์'));
    await tester.pumpAndSettle();

    await tapVisible(tester, 'ลบกิจกรรมนี้');
    expect(find.text('ลบเฉพาะวันนี้'), findsOneWidget);
    await tester.tap(find.text('ลบทุกวัน (3)'));
    await tester.pumpAndSettle();

    expect(repo.getAll().map((e) => e.id), ['thu']);
  });

  testWidgets('มุมมองเดือนแสดงปฏิทิน แตะวันที่แล้วเห็นกิจกรรมของวันนั้น', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('เดือน'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(find.text(CalendarUtils.thaiMonthYear(now)), findsOneWidget);

    // แตะวันพฤหัสบดีแรกของเดือนนี้
    final thursday = CalendarUtils.monthGrid(now.year, now.month)
        .firstWhere((d) => d.month == now.month && d.weekday == DateTime.thursday);
    final cell = find.byKey(ValueKey('month-cell-${thursday.year}-${thursday.month}-${thursday.day}'));
    await tester.ensureVisible(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();

    expect(find.text('นัดลูกค้าพฤหัส'), findsOneWidget);
    expect(find.text('วิ่งเช้าวันจันทร์'), findsNothing);

    // เลื่อนไปเดือนถัดไป
    final next = CalendarUtils.addMonths(DateTime(now.year, now.month), 1);
    // ensureVisible ข้างบนอาจเลื่อนหัวปฏิทินพ้นจอ (ขึ้นกับวันที่รันเทสต์) — เลื่อนกลับมาก่อนแตะ
    await tester.ensureVisible(find.byTooltip('ถัดไป'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ถัดไป'));
    await tester.pumpAndSettle();
    expect(find.text(CalendarUtils.thaiMonthYear(next)), findsOneWidget);
  });

  testWidgets('มุมมองปีแสดงครบ 12 เดือน แตะเดือนเพื่อเปิดปฏิทินรายเดือน', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('ปี'));
    await tester.pumpAndSettle();

    final year = DateTime.now().year;
    expect(find.text('ปี ${year + 543} ($year)'), findsOneWidget);
    for (var m = 1; m <= 12; m++) {
      expect(find.byKey(ValueKey('mini-month-$year-$m'), skipOffstage: false), findsOneWidget);
    }

    final march = find.byKey(ValueKey('mini-month-$year-3'));
    await tester.tap(march);
    await tester.pumpAndSettle();
    expect(find.text('มีนาคม ${year + 543}'), findsOneWidget);
  });
}
