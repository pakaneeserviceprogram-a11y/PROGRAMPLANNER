import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/client_repository.dart';
import 'package:lifeplan_app/models/client.dart';
import 'package:lifeplan_app/screens/client_detail_screen.dart';
import 'package:lifeplan_app/screens/crm_screen.dart';

/// แผนประกัน / การเข้าพบพร้อมของขวัญ / วันติดตาม ของลูกค้าแต่ละราย
void main() {
  const somchai = Client(
    id: 'c1',
    name: 'คุณสมชาย ใจดี',
    initials: 'สช',
    policyLabel: 'ประกันสุขภาพ',
    stage: ClientStage.contacted,
  );

  group('Client model', () {
    test('ลูกค้าเก่าที่ยังไม่มีแผน/การเข้าพบ/วันติดตาม อ่านได้เป็นค่าว่าง', () {
      final old = Client.fromMap({
        'id': 'c1', 'name': 'คุณเก่า', 'initials': 'คก', 'policyLabel': 'x', 'stage': 'newLead',
      });
      expect(old.plans, isEmpty);
      expect(old.visits, isEmpty);
      expect(old.followUpAt, isNull);
    });

    test('บันทึกแล้วอ่านกลับได้ครบ และเรียงการเข้าพบใหม่ → เก่า', () {
      final client = somchai.copyWith(
        plans: const [
          InsurancePlan(id: 'p1', name: 'สุขภาพเหมาจ่าย', sumInsured: 5000000, annualPremium: 30000, status: PlanStatus.active),
        ],
        visits: [
          ClientVisit(id: 'v1', date: DateTime(2026, 9, 1), gift: 'กระเช้าผลไม้'),
          ClientVisit(id: 'v2', date: DateTime(2026, 9, 20), note: 'นำเสนอแผน'),
        ],
        followUpAt: DateTime(2026, 10, 10, 14, 30),
        followUpNote: 'ถามผลตัดสินใจ',
      );
      final back = Client.fromMap(client.toMap());
      expect(back.plans.single.name, 'สุขภาพเหมาจ่าย');
      expect(back.plans.single.status, PlanStatus.active);
      expect(back.visits.map((v) => v.id), ['v2', 'v1']);
      expect(back.visits.last.gift, 'กระเช้าผลไม้');
      expect(back.followUpAt, DateTime(2026, 10, 10, 14, 30));
      expect(back.followUpNote, 'ถามผลตัดสินใจ');
    });

    test('เบี้ยรวมไม่นับแผนที่ลูกค้าไม่สนใจ', () {
      final client = somchai.copyWith(plans: const [
        InsurancePlan(id: 'a', name: 'A', annualPremium: 20000, status: PlanStatus.active),
        InsurancePlan(id: 'b', name: 'B', annualPremium: 15000),
        InsurancePlan(id: 'c', name: 'C', annualPremium: 99000, status: PlanStatus.declined),
      ]);
      expect(client.plansPremium, 35000);
    });

    test('ถึงกำหนดติดตามเมื่อเลยเวลาแล้ว และล้างวันติดตามได้', () {
      final client = somchai.copyWith(followUpAt: DateTime(2026, 10, 1, 9));
      expect(client.isFollowUpDue(now: DateTime(2026, 10, 1, 8, 59)), isFalse);
      expect(client.isFollowUpDue(now: DateTime(2026, 10, 1, 9)), isTrue);
      expect(client.copyWith(clearFollowUp: true).followUpAt, isNull);
    });
  });

  group('หน้ารายละเอียดลูกค้า', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.clients, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.weeklyReports, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.userProfile, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
      ]);
      await ClientRepository().put(somchai);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    Client stored() => ClientRepository().getAll().single;

    Future<void> pumpDetail(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ClientDetailScreen(clientId: 'c1')));
      await tester.pump();
    }

    Future<void> submit(WidgetTester tester) async {
      final save = find.text('บันทึก').last;
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    testWidgets('เพิ่มแผนประกันแล้วเบี้ยของลูกค้าตามผลรวมของแผน', (tester) async {
      await pumpDetail(tester);
      await tester.tap(find.text('+ เพิ่มแผน'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'เช่น สุขภาพเหมาจ่าย 5 ล้าน'), 'สุขภาพเหมาจ่าย');
      await tester.enterText(find.widgetWithText(TextField, '1000000'), '5000000');
      await tester.enterText(find.widgetWithText(TextField, '25000'), '30000');
      await submit(tester);

      final plan = stored().plans.single;
      expect(plan.name, 'สุขภาพเหมาจ่าย');
      expect(plan.sumInsured, 5000000);
      expect(stored().premiumAmount, 30000);
      expect(find.text('สุขภาพเหมาจ่าย'), findsOneWidget);
      expect(find.textContaining('เบี้ยรวม ฿30,000'), findsOneWidget);
    });

    testWidgets('บันทึกการเข้าพบพร้อมของขวัญ', (tester) async {
      await pumpDetail(tester);
      await tester.ensureVisible(find.text('+ บันทึก'));
      await tester.tap(find.text('+ บันทึก'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'เช่น กระเช้าผลไม้'), 'กระเช้าผลไม้');
      await submit(tester);

      final visit = stored().visits.single;
      expect(visit.gift, 'กระเช้าผลไม้');
      expect(find.text('ของขวัญ: กระเช้าผลไม้'), findsOneWidget);
    });

    testWidgets('ตั้งวันติดตาม "อีก 7 วัน" แล้วกดติดตามแล้วจะล้างวันติดตาม', (tester) async {
      await pumpDetail(tester);
      await tester.tap(find.text('ตั้งวัน'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('อีก 7 วัน'));
      await tester.enterText(find.widgetWithText(TextField, 'เช่น ถามผลตัดสินใจแผนสุขภาพ'), 'ถามผลตัดสินใจ');
      await submit(tester);

      final now = DateTime.now();
      final at = stored().followUpAt!;
      expect(DateTime(at.year, at.month, at.day), DateTime(now.year, now.month, now.day + 7));
      expect(stored().followUpNote, 'ถามผลตัดสินใจ');
      expect(find.byKey(const ValueKey('follow-up-text')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('follow-up-done')));
      await tester.pumpAndSettle();
      expect(stored().followUpAt, isNull);
      // ติดตามแล้วเปิดฟอร์มบันทึกการเข้าพบต่อให้ทันที
      expect(find.text('บันทึกการเข้าพบ'), findsOneWidget);
    });

    testWidgets('รายชื่อลูกค้า: แตะชื่อเปิดหน้ารายละเอียด แตะป้ายสถานะเลื่อนขั้น และแก้ไขลูกค้าแล้วแผนไม่หาย',
        (tester) async {
      await ClientRepository().put(somchai.copyWith(
        plans: const [InsurancePlan(id: 'p1', name: 'สุขภาพเหมาจ่าย', annualPremium: 30000)],
        followUpAt: DateTime.now().add(const Duration(days: 3)),
      ));
      await tester.pumpWidget(const MaterialApp(home: CrmScreen()));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('คุณสมชาย ใจดี'), 250);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('follow-up-c1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('stage-c1')));
      await tester.pumpAndSettle();
      expect(stored().stage, ClientStage.proposalSent);

      // แก้ไขผ่านฟอร์มเดิม (รูปดินสอ) ต้องไม่ลบแผน/วันติดตามทิ้ง
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await submit(tester);
      expect(stored().plans.single.name, 'สุขภาพเหมาจ่าย');
      expect(stored().followUpAt, isNotNull);

      await tester.tap(find.text('คุณสมชาย ใจดี'));
      await tester.pumpAndSettle();
      expect(find.byType(ClientDetailScreen), findsOneWidget);
      expect(find.text('สุขภาพเหมาจ่าย'), findsOneWidget);
    });
  });
}
