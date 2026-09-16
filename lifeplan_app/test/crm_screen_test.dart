import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/weekly_report_repository.dart';
import 'package:lifeplan_app/models/weekly_report.dart';
import 'package:lifeplan_app/screens/crm_screen.dart';

/// box แบบ in-memory (bytes:) เหมือน nutrition_screen_test — การเขียนไม่แตะไฟล์จริง
/// จึงจบได้ภายใน FakeAsync ของ testWidgets
void main() {
  late DateTime thisWeek;

  setUp(() async {
    await setUpTestHive();
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.clients, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.weeklyReports, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.userProfile, bytes: Uint8List(0)),
    ]);

    thisWeek = WeeklyReport.startOfWeek(DateTime.now());
    await WeeklyReportRepository().put(WeeklyReport(
      weekStart: thisWeek,
      ownerName: 'เอ๋',
      salesPremium: 60000,
      activities: const {
        ActivityCode.prospect: WeeklyActivity(count: 5),
        ActivityCode.appointment: WeeklyActivity(count: 3, note: 'ลูกค้าใหม่ 3'),
        ActivityCode.sales: WeeklyActivity(count: 2, note: 'ขาย Offline'),
        ActivityCode.referral: WeeklyActivity(count: 1),
        ActivityCode.followUp: WeeklyActivity(count: 2, note: 'ติดต่อทางไลน์ค่ะ'),
        ActivityCode.newMarket: WeeklyActivity(count: 1, note: 'ทักลูกค้าจากเพื่อนแนะนำค่ะ'),
        ActivityCode.team: WeeklyActivity(count: 0),
      },
    ));
  });

  tearDown(() async {
    await Hive.close();
    await tearDownTestHive();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CrmScreen()));
    await tester.pump();
  }

  String weekLabel(DateTime weekStart) =>
      WeeklyReport(weekStart: weekStart).weekRangeLabel;

  testWidgets('แสดงรายงาน P-A-S-R-F-N-T ของสัปดาห์นี้', (tester) async {
    await pumpScreen(tester);

    expect(find.text('รายงานผลงานประจำสัปดาห์'), findsOneWidget);
    expect(find.text('สัปดาห์ที่ ${weekLabel(thisWeek)}'), findsOneWidget);

    // ตัวอย่างข้อความที่จะส่งหัวหน้า ประกอบจากตัวเลข + หมายเหตุที่บันทึกไว้
    final preview = tester.widget<Text>(find.textContaining('S = 2 ราย เบี้ยประมาณ 60,000 บาท (ขาย Offline)'));
    expect(preview.data, contains('ตารางทำงานเอ๋ ประจำสัปดาห์ที่ ${weekLabel(thisWeek)}'));
    expect(preview.data, contains('A = 3 (ลูกค้าใหม่ 3)'));
    expect(preview.data, contains('T = 0'));

    expect(find.text('฿60,000'), findsOneWidget);
  });

  testWidgets('เลื่อนย้อนสัปดาห์แล้วเจอสัปดาห์ที่ยังไม่ได้บันทึก', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();

    final lastWeek = thisWeek.subtract(const Duration(days: 7));
    expect(find.text('สัปดาห์ที่ ${weekLabel(lastWeek)}'), findsOneWidget);
    expect(find.text('ยังไม่ได้บันทึก'), findsOneWidget);
    expect(find.textContaining('กด “แก้ไข” เพื่อบันทึก'), findsOneWidget);
  });

  testWidgets('กดคัดลอกแล้วได้ข้อความรายงานเต็มลงคลิปบอร์ด', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpScreen(tester);

    final copyButton = find.text('คัดลอกส่งหัวหน้า');
    await tester.scrollUntilVisible(copyButton, 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.ensureVisible(copyButton);
    await tester.pump();
    await tester.tap(copyButton);
    await tester.pump();

    expect(copied, isNotNull);
    expect(copied, contains('ตารางทำงานเอ๋ ประจำสัปดาห์ที่ ${weekLabel(thisWeek)}'));
    expect(copied, contains('P = Prospect, A = Appointment, S = Sales, R = Referal, F = Follow, N = New Market, T = Team'));
    expect(copied, contains('N = 1 (ทักลูกค้าจากเพื่อนแนะนำค่ะ)'));
    expect(find.text('คัดลอกรายงานแล้ว — วางส่งหัวหน้าได้เลย'), findsOneWidget);
  });
}
