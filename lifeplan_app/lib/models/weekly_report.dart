/// รายงานผลงานประจำสัปดาห์ของเอเจนต์ (P-A-S-R-F-N-T) — ตัวเลขที่ส่งให้หัวหน้า
/// ทุกสัปดาห์ และใช้ตามความคืบหน้าของงานขายย้อนหลังได้
///
/// P = Prospect, A = Appointment, S = Sales, R = Referal,
/// F = Follow, N = New Market, T = Team
enum ActivityCode { prospect, appointment, sales, referral, followUp, newMarket, team }

extension ActivityCodeX on ActivityCode {
  /// ตัวย่อที่ใช้ในรายงาน — ต้องตรงกับที่หัวหน้าใช้อ่าน
  String get letter => switch (this) {
        ActivityCode.prospect => 'P',
        ActivityCode.appointment => 'A',
        ActivityCode.sales => 'S',
        ActivityCode.referral => 'R',
        ActivityCode.followUp => 'F',
        ActivityCode.newMarket => 'N',
        ActivityCode.team => 'T',
      };

  String get englishLabel => switch (this) {
        ActivityCode.prospect => 'Prospect',
        ActivityCode.appointment => 'Appointment',
        ActivityCode.sales => 'Sales',
        ActivityCode.referral => 'Referal',
        ActivityCode.followUp => 'Follow',
        ActivityCode.newMarket => 'New Market',
        ActivityCode.team => 'Team',
      };

  String get label => switch (this) {
        ActivityCode.prospect => 'ผู้มุ่งหวัง',
        ActivityCode.appointment => 'นัดหมาย',
        ActivityCode.sales => 'ปิดการขาย',
        ActivityCode.referral => 'ลูกค้าแนะนำต่อ',
        ActivityCode.followUp => 'ติดตามผล',
        ActivityCode.newMarket => 'ตลาดใหม่',
        ActivityCode.team => 'ทีมงาน',
      };

  /// ตัวอย่างสิ่งที่ควรกรอกในช่องหมายเหตุของแต่ละตัวย่อ
  String get noteHint => switch (this) {
        ActivityCode.prospect => 'เช่น รายชื่อจากงานสัมมนา',
        ActivityCode.appointment => 'เช่น ลูกค้าใหม่ 3',
        ActivityCode.sales => 'เช่น ขาย Offline',
        ActivityCode.referral => 'เช่น ลูกค้าเก่าแนะนำ',
        ActivityCode.followUp => 'เช่น ติดต่อทางไลน์ค่ะ',
        ActivityCode.newMarket => 'เช่น ทักลูกค้าจากเพื่อนแนะนำค่ะ',
        ActivityCode.team => 'เช่น ชวนเพื่อนร่วมทีม',
      };
}

/// ตัวเลขหนึ่งช่องในรายงาน พร้อมหมายเหตุสั้น ๆ ที่จะต่อท้ายบรรทัดตอนส่งหัวหน้า
class WeeklyActivity {
  final int count;
  final String note;

  const WeeklyActivity({this.count = 0, this.note = ''});

  bool get isBlank => count == 0 && note.isEmpty;

  WeeklyActivity copyWith({int? count, String? note}) =>
      WeeklyActivity(count: count ?? this.count, note: note ?? this.note);

  Map<String, dynamic> toMap() => {'count': count, 'note': note};

  factory WeeklyActivity.fromMap(Map<String, dynamic> map) => WeeklyActivity(
        count: (map['count'] as num?)?.toInt() ?? 0,
        note: map['note'] as String? ?? '',
      );
}

class WeeklyReport {
  /// วันจันทร์ของสัปดาห์ที่วันนั้นอยู่ — ทุกสัปดาห์เริ่มวันจันทร์เหมือนหน้าตารางเวลา
  static DateTime startOfWeek(DateTime day) =>
      DateTime(day.year, day.month, day.day).subtract(Duration(days: day.weekday - 1));

  /// คีย์ yyyy-MM-dd ของวันจันทร์ — ใช้เป็น id เพื่อให้บันทึกซ้ำทับสัปดาห์เดิมเสมอ
  static String weekKeyOf(DateTime day) {
    final s = startOfWeek(day);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${s.year}-${two(s.month)}-${two(s.day)}';
  }

  /// วันที่แบบไทยย่อ เช่น 29/4/67 (พ.ศ. สองหลักท้าย) — รูปแบบเดียวกับที่ส่งหัวหน้า
  static String thaiShortDate(DateTime d) =>
      '${d.day}/${d.month}/${((d.year + 543) % 100).toString().padLeft(2, '0')}';

  final String id; // = weekKey
  final DateTime weekStart;

  /// ชื่อที่ขึ้นหัวรายงาน เช่น "ตารางทำงานเอ๋ ประจำสัปดาห์ที่ ..."
  final String ownerName;
  final Map<ActivityCode, WeeklyActivity> activities;

  /// เบี้ยประกันโดยประมาณของยอดขาย (S) ในสัปดาห์นี้ (บาท)
  final double salesPremium;

  WeeklyReport({
    required DateTime weekStart,
    this.ownerName = '',
    Map<ActivityCode, WeeklyActivity>? activities,
    this.salesPremium = 0,
  })  : id = weekKeyOf(weekStart),
        weekStart = startOfWeek(weekStart),
        activities = Map.unmodifiable(activities ?? const <ActivityCode, WeeklyActivity>{});

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  int countOf(ActivityCode code) => activities[code]?.count ?? 0;

  String noteOf(ActivityCode code) => activities[code]?.note ?? '';

  /// ยังไม่ได้กรอกอะไรเลย — ใช้ตัดสินว่าจะโชว์สถานะ "ยังไม่ได้บันทึก"
  bool get isBlank =>
      salesPremium == 0 &&
      ActivityCode.values.every((c) => (activities[c] ?? const WeeklyActivity()).isBlank);

  /// ช่วงสัปดาห์แบบที่ใช้ในหัวรายงาน เช่น 29/4/67-5/5/67
  String get weekRangeLabel => '${thaiShortDate(weekStart)}-${thaiShortDate(weekEnd)}';

  WeeklyReport copyWith({
    String? ownerName,
    Map<ActivityCode, WeeklyActivity>? activities,
    double? salesPremium,
  }) =>
      WeeklyReport(
        weekStart: weekStart,
        ownerName: ownerName ?? this.ownerName,
        activities: activities ?? this.activities,
        salesPremium: salesPremium ?? this.salesPremium,
      );

  WeeklyReport withActivity(ActivityCode code, WeeklyActivity activity) =>
      copyWith(activities: {...activities, code: activity});

  static String formatMoney(double value) =>
      value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  /// หนึ่งบรรทัดของรายงาน เช่น `A = 3 (ลูกค้าใหม่ 3)`
  /// บรรทัด S จะพ่วงเบี้ยประกันให้อัตโนมัติเมื่อกรอกไว้
  String lineOf(ActivityCode code) {
    final buffer = StringBuffer('${code.letter} = ${countOf(code)}');
    if (code == ActivityCode.sales && salesPremium > 0) {
      buffer.write(' ราย เบี้ยประมาณ ${formatMoney(salesPremium)} บาท');
    }
    final note = noteOf(code);
    if (note.isNotEmpty) buffer.write(' ($note)');
    return buffer.toString();
  }

  /// ข้อความรายงานฉบับเต็มที่ก๊อบไปส่งหัวหน้าทางไลน์ได้ทันที
  String toReportText() {
    final owner = ownerName.trim();
    return [
      'ตารางทำงาน$owner ประจำสัปดาห์ที่ $weekRangeLabel',
      '',
      ActivityCode.values.map((c) => '${c.letter} = ${c.englishLabel}').join(', '),
      '',
      ...ActivityCode.values.map(lineOf),
    ].join('\n');
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'weekStart': weekStart.toIso8601String(),
        'ownerName': ownerName,
        'salesPremium': salesPremium,
        'activities': {
          for (final entry in activities.entries) entry.key.name: entry.value.toMap(),
        },
      };

  factory WeeklyReport.fromMap(Map<String, dynamic> map) {
    final rawActivities = map['activities'];
    final activities = <ActivityCode, WeeklyActivity>{};
    if (rawActivities is Map) {
      for (final code in ActivityCode.values) {
        final raw = rawActivities[code.name];
        if (raw is Map) activities[code] = WeeklyActivity.fromMap(Map<String, dynamic>.from(raw));
      }
    }
    return WeeklyReport(
      weekStart: DateTime.tryParse(map['weekStart'] as String? ?? '') ?? DateTime.now(),
      ownerName: map['ownerName'] as String? ?? '',
      activities: activities,
      salesPremium: (map['salesPremium'] as num?)?.toDouble() ?? 0,
    );
  }
}
