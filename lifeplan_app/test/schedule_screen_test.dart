import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/schedule_repository.dart';
import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';
import 'package:lifeplan_app/screens/schedule_screen.dart';

/// กิจกรรมถูกเขียนลง Hive ใน setUp (นอก FakeAsync ของ testWidgets) แล้วค่อย pump
/// หน้าจอ — เลี่ยงปัญหา pumpAndSettle() ไม่รอ file I/O จริงที่อธิบายไว้ใน widget_test.dart
void main() {
  setUp(() async {
    await setUpTestHive();
    await Hive.openBox<Map>(HiveBoxes.scheduleEvents);

    final repo = ScheduleRepository();
    await repo.put(const ScheduleEvent(
        id: 'mon', time: '07:00', weekday: DateTime.monday, title: 'วิ่งเช้าวันจันทร์', category: LifeCategory.exercise));
    await repo.put(const ScheduleEvent(
        id: 'thu', time: '15:00', weekday: DateTime.thursday, title: 'นัดลูกค้าพฤหัส', category: LifeCategory.crm));
  });

  tearDown(tearDownTestHive);

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
}
