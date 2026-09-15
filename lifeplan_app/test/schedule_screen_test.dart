import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

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
}
