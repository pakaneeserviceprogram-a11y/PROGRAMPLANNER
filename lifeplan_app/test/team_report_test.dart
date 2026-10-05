import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/client_repository.dart';
import 'package:lifeplan_app/data/repositories/schedule_repository.dart';
import 'package:lifeplan_app/data/team_report.dart';
import 'package:lifeplan_app/models/client.dart';
import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';
import 'package:lifeplan_app/models/weekly_report.dart';
import 'package:lifeplan_app/screens/crm_screen.dart';

/// ส่งงานขายให้หัวหน้าทาง LINE: เติมรายงานอัตโนมัติ + สรุปพอร์ต
void main() {
  // จันทร์ 28 ก.ย. 2026 – อาทิตย์ 4 ต.ค. 2026
  final week = DateTime(2026, 9, 28);
  final inWeek = DateTime(2026, 9, 30, 10);
  final lastWeek = DateTime(2026, 9, 25, 10);

  Client client(String id, {DateTime? createdAt, ClientSource source = ClientSource.unknown,
          ClientStage stage = ClientStage.newLead, List<InsurancePlan> plans = const [],
          List<ClientVisit> visits = const [], DateTime? followUpAt, String? followUpNote, double premium = 0}) =>
      Client(
        id: id,
        name: 'คุณ$id',
        initials: id,
        policyLabel: 'x',
        stage: stage,
        premiumAmount: premium,
        createdAt: createdAt,
        source: source,
        plans: plans,
        visits: visits,
        followUpAt: followUpAt,
        followUpNote: followUpNote,
      );

  group('TeamReport.weeklyCounts', () {
    test('นับ P/R/A/S/F เฉพาะของสัปดาห์นั้น และไม่นับลูกค้าเก่าที่ไม่มีวันที่เพิ่ม', () {
      final clients = [
        client('a', createdAt: inWeek, source: ClientSource.referral, visits: [
          ClientVisit(id: 'v1', date: inWeek),
          ClientVisit(id: 'v2', date: lastWeek),
        ]),
        client('b', createdAt: inWeek, plans: [
          InsurancePlan(id: 'p1', name: 'A', annualPremium: 30000, status: PlanStatus.active, closedAt: inWeek),
          InsurancePlan(id: 'p2', name: 'B', annualPremium: 99000, status: PlanStatus.active, closedAt: lastWeek),
          const InsurancePlan(id: 'p3', name: 'C', annualPremium: 5000),
        ]),
        client('c', createdAt: lastWeek),
        client('old'), // ก่อนมีฟิลด์ createdAt
      ];
      final events = [
        ScheduleEvent.oneOff(id: 'e1', time: '10:00', date: DateTime(2026, 10, 4), title: 'นัด',
            category: LifeCategory.crm, clientId: 'a'),
        ScheduleEvent.oneOff(id: 'e2', time: '10:00', date: DateTime(2026, 10, 5), title: 'นัดสัปดาห์หน้า',
            category: LifeCategory.crm, clientId: 'a'),
        ScheduleEvent.oneOff(id: 'e3', time: '10:00', date: DateTime(2026, 9, 29), title: 'ไม่ใช่นัดลูกค้า',
            category: LifeCategory.work),
      ];

      final counts = TeamReport.weeklyCounts(clients: clients, events: events, weekStart: week);
      expect(counts.prospect, 2);
      expect(counts.referral, 1);
      expect(counts.appointment, 1);
      expect(counts.sales, 1);
      expect(counts.salesPremium, 30000);
      expect(counts.followUp, 1);
      expect(counts.countOf(ActivityCode.newMarket), isNull);
      expect(counts.countOf(ActivityCode.team), isNull);
    });
  });

  group('TeamReport.portfolioText', () {
    final now = DateTime(2026, 10, 1, 9);
    final clients = [
      client('สมชาย', stage: ClientStage.closedWon, premium: 40000),
      client('มานี', stage: ClientStage.proposalSent, plans: const [
        InsurancePlan(id: 'p', name: 'สุขภาพเหมาจ่าย', annualPremium: 25000),
        InsurancePlan(id: 'q', name: 'ไม่เอาแล้ว', annualPremium: 9000, status: PlanStatus.declined),
      ], followUpAt: DateTime(2026, 9, 30, 10), followUpNote: 'ถามผลตัดสินใจ'),
      client('ปิติ', followUpAt: DateTime(2026, 10, 5, 10)),
      client('ไกลมาก', followUpAt: DateTime(2026, 11, 1, 10)),
    ];

    test('ค่าเริ่มต้นไม่มีชื่อลูกค้า แต่มีตัวเลขสรุปครบ', () {
      final text = TeamReport.portfolioText(
          clients: clients, ownerName: 'เอ๋', salesTarget: 100000, now: now);
      expect(text, contains('สรุปพอร์ตลูกค้า เอ๋'));
      expect(text, contains('ลูกค้าทั้งหมด 4 ราย'));
      expect(text, contains('เบี้ยที่ปิดได้ ฿40,000 / เป้า ฿100,000 (40%)'));
      expect(text, contains('แผนที่เสนอค้างอยู่ 1 แผน รวม ฿25,000/ปี'));
      expect(text, contains('ต้องติดตามภายใน 7 วัน 2 ราย (เลยกำหนด 1 ราย)'));
      for (final name in ['สมชาย', 'มานี', 'ปิติ', 'สุขภาพเหมาจ่าย']) {
        expect(text, isNot(contains(name)), reason: name);
      }
    });

    test('เปิดใส่ชื่อแล้วมีรายชื่อแผนค้างและรายที่ต้องติดตาม', () {
      final text = TeamReport.portfolioText(
          clients: clients, ownerName: 'เอ๋', salesTarget: 100000, now: now, includeNames: true);
      expect(text, contains('• คุณมานี — สุขภาพเหมาจ่าย (เสนอแล้ว ฿25,000/ปี)'));
      expect(text, contains('คุณมานี — ถามผลตัดสินใจ'));
      expect(text, contains('คุณปิติ'));
      expect(text, isNot(contains('คุณไกลมาก')));
    });
  });

  test('ลิงก์แชร์ LINE เข้ารหัสข้อความภาษาไทยและขึ้นบรรทัดใหม่', () {
    final uri = LineShare.uriFor('รายงาน\nP 5');
    expect(uri.host, 'line.me');
    expect(uri.path, '/R/share');
    expect(uri.queryParameters['text'], 'รายงาน\nP 5');
  });

  group('หน้าลูกค้า: ส่งเข้า LINE', () {
    final sent = <Uri>[];

    setUp(() async {
      sent.clear();
      LineShare.launcher = (uri) async {
        sent.add(uri);
        return true;
      };
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.clients, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.weeklyReports, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.userProfile, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
      ]);
      final now = DateTime.now();
      await ClientRepository().put(client('มานี', createdAt: now, source: ClientSource.referral, visits: [
        ClientVisit(id: 'v', date: now),
      ]));
      await ScheduleRepository().put(ScheduleEvent.oneOff(
          id: 'e', time: '10:00', date: now, title: 'นัด', category: LifeCategory.crm, clientId: 'มานี'));
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    Future<void> pumpCrm(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: CrmScreen()));
      await tester.pump();
    }

    testWidgets('สรุปพอร์ต: ส่งเข้า LINE แบบไม่มีชื่อ แล้วเปิดใส่ชื่อได้', (tester) async {
      await pumpCrm(tester);
      await tester.tap(find.byKey(const ValueKey('open-portfolio-summary')));
      await tester.pumpAndSettle();

      expect(find.textContaining('คุณมานี'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('portfolio-send-line')));
      await tester.pumpAndSettle();
      expect(sent.single.queryParameters['text'], contains('ลูกค้าทั้งหมด 1 ราย'));
      expect(sent.single.queryParameters['text'], isNot(contains('มานี')));

      await tester.tap(find.byKey(const ValueKey('portfolio-include-names')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('portfolio-preview')), findsOneWidget);
    });

    testWidgets('รายงานสัปดาห์: เติมตัวเลขจากข้อมูลในแอป บันทึก แล้วส่งเข้า LINE', (tester) async {
      await pumpCrm(tester);
      final edit = find.text('แก้ไข');
      await tester.scrollUntilVisible(edit, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(edit);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('report-autofill')));
      await tester.pumpAndSettle();
      final save = find.text('บันทึกรายงาน');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      // รอ snackbar "เติมตัวเลขแล้ว" หายไปก่อน ไม่งั้นมันบังปุ่มด้านล่าง
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final sendLine = find.byKey(const ValueKey('report-send-line'));
      await tester.scrollUntilVisible(sendLine, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(sendLine);
      await tester.pumpAndSettle();
      await tester.tap(sendLine);
      await tester.pumpAndSettle();

      final text = sent.single.queryParameters['text']!;
      expect(text, contains('P = 1'));
      expect(text, contains('A = 1'));
      expect(text, contains('R = 1'));
      expect(text, contains('F = 1'));
    });
  });
}
