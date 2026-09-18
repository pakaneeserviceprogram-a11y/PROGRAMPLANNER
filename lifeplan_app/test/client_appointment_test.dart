import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/calendar_utils.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/client_repository.dart';
import 'package:lifeplan_app/data/repositories/schedule_repository.dart';
import 'package:lifeplan_app/models/client.dart';
import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';
import 'package:lifeplan_app/screens/crm_screen.dart';

/// นัดลูกค้าจากหน้า CRM — เป็นกิจกรรมเฉพาะวันที่ที่ผูก clientId ไว้
/// จึงดึงนัดถัดไปมาโชว์ในรายชื่อได้ แม้ผู้ใช้เปลี่ยนชื่อลูกค้าภายหลัง
void main() {
  const client = Client(
    id: 'c1',
    name: 'คุณสมชาย ใจดี',
    initials: 'สม',
    policyLabel: 'ประกันสุขภาพ • ลูกค้าใหม่',
    stage: ClientStage.newLead,
  );

  ScheduleEvent appointment(String id, DateTime date, String time, {String clientId = 'c1'}) =>
      ScheduleEvent.oneOff(
        id: id,
        time: time,
        date: date,
        title: 'นัด ${client.name}',
        category: LifeCategory.crm,
        clientId: clientId,
      );

  setUp(() async {
    await setUpTestHive();
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.clients, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.weeklyReports, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.userProfile, bytes: Uint8List(0)),
    ]);
    await ClientRepository().put(client);
  });

  tearDown(() async {
    await Hive.close();
    await tearDownTestHive();
  });

  group('ScheduleEvent.clientId', () {
    test('เก็บและอ่านกลับได้ ส่วนกิจกรรมทั่วไปยังเป็น null', () {
      final map = appointment('a1', DateTime(2026, 10, 2), '10:30').toMap();
      expect(map['clientId'], 'c1');
      expect(ScheduleEvent.fromMap(Map<String, dynamic>.from(map)).clientId, 'c1');

      const plain = ScheduleEvent(id: 'x', time: '07:00', title: 'วิ่ง', category: LifeCategory.exercise);
      expect(ScheduleEvent.fromMap(Map<String, dynamic>.from(plain.toMap())).clientId, isNull);
    });
  });

  group('นัดถัดไปของลูกค้า', () {
    test('เรียงจากใกล้ที่สุด และข้ามนัดที่ผ่านไปแล้ว', () async {
      final repo = ScheduleRepository();
      final now = DateTime(2026, 10, 1);
      await repo.put(appointment('past', DateTime(2026, 9, 20), '09:00'));
      await repo.put(appointment('later', DateTime(2026, 10, 9), '09:00'));
      await repo.put(appointment('soon', DateTime(2026, 10, 2), '15:00'));

      expect(repo.upcomingForClient('c1', from: now).map((e) => e.id), ['soon', 'later']);
      expect(repo.nextForClient('c1', from: now)!.id, 'soon');
    });

    test('นัดของวันนี้ยังนับว่ายังมาไม่ถึง', () async {
      final repo = ScheduleRepository();
      final now = DateTime(2026, 10, 1, 18);
      await repo.put(appointment('today', DateTime(2026, 10, 1), '09:00'));
      expect(repo.nextForClient('c1', from: now)!.id, 'today');
    });

    test('ไม่ปนกับนัดของลูกค้าคนอื่นหรือกิจกรรมทั่วไป', () async {
      final repo = ScheduleRepository();
      final now = DateTime(2026, 10, 1);
      await repo.put(appointment('other', DateTime(2026, 10, 3), '09:00', clientId: 'c2'));
      await repo.put(ScheduleEvent.oneOff(
        id: 'plain',
        time: '09:00',
        date: DateTime(2026, 10, 3),
        title: 'ประชุม',
        category: LifeCategory.work,
      ));

      expect(repo.nextForClient('c1', from: now), isNull);
      expect(repo.nextForClient('c2', from: now)!.id, 'other');
    });
  });

  group('หน้าลูกค้า', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: CrmScreen()));
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

    testWidgets('นัดหมายจากฟอร์มแก้ไข แล้วได้กิจกรรมเฉพาะวันที่ผูกกับลูกค้า', (tester) async {
      await pumpScreen(tester);
      await tester.scrollUntilVisible(find.byIcon(Icons.edit_outlined), 250);
      await tapVisible(tester, find.byIcon(Icons.edit_outlined));
      await tapVisible(tester, find.text('นัดหมายลูกค้ารายนี้'));

      expect(find.text('นัดหมาย ${client.name}'), findsOneWidget);
      // ค่าเริ่มต้น: วันนี้ 10:00 และรายละเอียดเติมความสนใจของลูกค้าไว้ให้
      expect(find.byKey(const ValueKey('appointment-date-field')), findsOneWidget);
      expect(find.widgetWithText(TextField, 'ประกันสุขภาพ'), findsOneWidget);

      await tapVisible(tester, find.text('เพิ่มลงตารางเวลา'));

      final saved = ScheduleRepository().getAll().single;
      final today = CalendarUtils.dateOnly(DateTime.now());
      expect(saved.clientId, 'c1');
      expect(saved.date, today);
      expect(saved.time, '10:00');
      expect(saved.title, 'นัด ${client.name}');
      expect(saved.subtitle, 'ประกันสุขภาพ');
      expect(saved.category, LifeCategory.crm);
    });

    testWidgets('รายชื่อลูกค้าแสดงนัดถัดไป', (tester) async {
      final soon = CalendarUtils.addDays(DateTime.now(), 3);
      await ScheduleRepository().put(appointment('a1', soon, '13:30'));

      await pumpScreen(tester);
      await tester.scrollUntilVisible(find.textContaining('นัด ${CalendarUtils.thaiDateShort(soon)}'), 250);
      await tester.pumpAndSettle();

      expect(find.text('นัด ${CalendarUtils.thaiDateShort(soon)} 13:30 น.'), findsOneWidget);
    });
  });
}
