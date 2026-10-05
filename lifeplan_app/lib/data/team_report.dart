import 'package:url_launcher/url_launcher.dart';

import '../models/client.dart';
import '../models/schedule_event.dart';
import '../models/weekly_report.dart';
import 'calendar_utils.dart';

/// ตัวเลขรายงาน P-A-S-R-F ที่นับได้จากข้อมูลที่บันทึกในแอป
///
/// N (ตลาดใหม่) และ T (ทีมงาน) ไม่มีข้อมูลในแอปให้นับ — ผู้ใช้กรอกเอง
class WeeklyAutoCounts {
  /// ลูกค้าใหม่ที่เพิ่มในสัปดาห์
  final int prospect;

  /// นัดลูกค้าในตารางเวลาที่ตกอยู่ในสัปดาห์
  final int appointment;

  /// แผนที่เปลี่ยนเป็น "กรมธรรม์มีผลแล้ว" ในสัปดาห์
  final int sales;

  /// ลูกค้าใหม่ในสัปดาห์ที่มาจากการแนะนำ
  final int referral;

  /// การเข้าพบที่บันทึกในสัปดาห์
  final int followUp;

  /// เบี้ยต่อปีรวมของแผนที่ปิดในสัปดาห์
  final double salesPremium;

  const WeeklyAutoCounts({
    this.prospect = 0,
    this.appointment = 0,
    this.sales = 0,
    this.referral = 0,
    this.followUp = 0,
    this.salesPremium = 0,
  });

  int? countOf(ActivityCode code) => switch (code) {
        ActivityCode.prospect => prospect,
        ActivityCode.appointment => appointment,
        ActivityCode.sales => sales,
        ActivityCode.referral => referral,
        ActivityCode.followUp => followUp,
        ActivityCode.newMarket || ActivityCode.team => null,
      };
}

/// สรุปงานขายส่งหัวหน้าทีม — ฟังก์ชันล้วน ไม่แตะ Hive จึงเทสต์ได้ตรง ๆ
class TeamReport {
  TeamReport._();

  static bool _inWeek(DateTime? d, DateTime weekStart) {
    if (d == null) return false;
    final end = weekStart.add(const Duration(days: 7));
    return !d.isBefore(weekStart) && d.isBefore(end);
  }

  static WeeklyAutoCounts weeklyCounts({
    required Iterable<Client> clients,
    required Iterable<ScheduleEvent> events,
    required DateTime weekStart,
  }) {
    final start = WeeklyReport.startOfWeek(weekStart);
    final newClients = clients.where((c) => _inWeek(c.createdAt, start)).toList();
    final closedPlans = [
      for (final c in clients)
        for (final p in c.plans)
          if (p.status == PlanStatus.active && _inWeek(p.closedAt, start)) p,
    ];

    return WeeklyAutoCounts(
      prospect: newClients.length,
      appointment: events.where((e) => e.clientId != null && _inWeek(e.date, start)).length,
      sales: closedPlans.length,
      referral: newClients.where((c) => c.source == ClientSource.referral).length,
      followUp: clients.expand((c) => c.visits).where((v) => _inWeek(v.date, start)).length,
      salesPremium: closedPlans.fold(0, (sum, p) => sum + p.annualPremium),
    );
  }

  /// ข้อความสรุปพอร์ตลูกค้า พร้อมวางใน LINE
  ///
  /// [includeNames] = false (ค่าเริ่มต้น) ไม่ใส่ชื่อลูกค้า — ข้อความมักถูกส่งเข้ากลุ่ม
  /// การส่งชื่อลูกค้าพร้อมแผนประกันต้องได้รับอนุญาตตาม PDPA
  static String portfolioText({
    required Iterable<Client> clients,
    required String ownerName,
    required double salesTarget,
    required DateTime now,
    bool includeNames = false,
  }) {
    final all = clients.toList();
    final today = CalendarUtils.dateOnly(now);
    final horizon = today.add(const Duration(days: 8)); // ถึงสิ้นวันที่ 7 นับจากวันนี้

    final closed = all.where((c) => c.stage == ClientStage.closedWon).toList();
    final achieved = closed.fold<double>(0, (sum, c) => sum + c.premiumAmount);
    final pendingPlans = [
      for (final c in all)
        for (final p in c.plans)
          if (p.status == PlanStatus.proposed || p.status == PlanStatus.applied) (client: c, plan: p),
    ];
    final pendingPremium = pendingPlans.fold<double>(0, (sum, e) => sum + e.plan.annualPremium);

    final followUps = all.where((c) => c.followUpAt != null && c.followUpAt!.isBefore(horizon)).toList()
      ..sort((a, b) => a.followUpAt!.compareTo(b.followUpAt!));
    final overdue = followUps.where((c) => c.isFollowUpDue(now: now)).length;

    final weekStart = WeeklyReport.startOfWeek(now);
    final visitsThisWeek = all.expand((c) => c.visits).where((v) => _inWeek(v.date, weekStart)).length;

    String money(double v) => '฿${WeeklyReport.formatMoney(v)}';
    final percent = salesTarget > 0 ? ' (${(achieved / salesTarget * 100).round()}%)' : '';
    final owner = ownerName.trim();

    return [
      'สรุปพอร์ตลูกค้า${owner.isEmpty ? '' : ' $owner'} ณ ${CalendarUtils.thaiDate(today)}',
      '',
      'ลูกค้าทั้งหมด ${all.length} ราย',
      for (final stage in ClientStage.values)
        '• ${stage.label} ${all.where((c) => c.stage == stage).length} ราย',
      '',
      'เบี้ยที่ปิดได้ ${money(achieved)} / เป้า ${money(salesTarget)}$percent',
      'แผนที่เสนอค้างอยู่ ${pendingPlans.length} แผน รวม ${money(pendingPremium)}/ปี',
      if (includeNames)
        for (final e in pendingPlans)
          '• ${e.client.name} — ${e.plan.name} (${e.plan.status.label}'
              '${e.plan.annualPremium > 0 ? ' ${money(e.plan.annualPremium)}/ปี' : ''})',
      'เข้าพบลูกค้าสัปดาห์นี้ $visitsThisWeek ครั้ง',
      '',
      'ต้องติดตามภายใน 7 วัน ${followUps.length} ราย${overdue > 0 ? ' (เลยกำหนด $overdue ราย)' : ''}',
      if (includeNames)
        for (final c in followUps)
          '• ${CalendarUtils.thaiDateShort(c.followUpAt!, now: now)} ${c.name}'
              '${c.followUpNote == null ? '' : ' — ${c.followUpNote}'}',
    ].join('\n');
  }
}

/// ส่งข้อความเข้า LINE ผ่านลิงก์แชร์ทางการของ LINE (เลือกห้องแชทในแอป LINE เอง)
///
/// ไม่มีแอป LINE ในเครื่อง ลิงก์จะเปิดในเบราว์เซอร์แทน
class LineShare {
  LineShare._();

  static Uri uriFor(String text) => Uri.parse('https://line.me/R/share?text=${Uri.encodeComponent(text)}');

  /// เปลี่ยนได้ในเทสต์ — ค่าจริงเปิดลิงก์ด้วยแอปภายนอก
  static Future<bool> Function(Uri uri) launcher =
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  static Future<bool> send(String text) async {
    try {
      return await launcher(uriFor(text));
    } catch (_) {
      return false;
    }
  }
}
