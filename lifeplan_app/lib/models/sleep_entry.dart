import 'meal_entry.dart';

/// คุณภาพการนอนที่ผู้ใช้ให้คะแนนเองตอนตื่น
enum SleepQuality { poor, fair, good, excellent }

/// สิ่งที่รบกวนการนอนของคืนนั้น — ติ๊กได้หลายข้อ ใช้หาสาเหตุที่นอนไม่ดีซ้ำ ๆ
enum SleepFactor { caffeine, lateMeal, screen, alcohol, stress, noise, lateExercise }

extension SleepQualityX on SleepQuality {
  String get label => switch (this) {
        SleepQuality.poor => 'แย่',
        SleepQuality.fair => 'พอใช้',
        SleepQuality.good => 'ดี',
        SleepQuality.excellent => 'ดีมาก',
      };

  /// น้ำหนัก 0–1 ที่เอาไปเฉลี่ยเป็นคะแนนคุณภาพการนอน
  double get weight => switch (this) {
        SleepQuality.poor => 0.25,
        SleepQuality.fair => 0.55,
        SleepQuality.good => 0.8,
        SleepQuality.excellent => 1.0,
      };
}

extension SleepFactorX on SleepFactor {
  String get label => switch (this) {
        SleepFactor.caffeine => 'คาเฟอีนตอนบ่าย-เย็น',
        SleepFactor.lateMeal => 'กินมื้อดึก',
        SleepFactor.screen => 'เล่นจอก่อนนอน',
        SleepFactor.alcohol => 'ดื่มแอลกอฮอล์',
        SleepFactor.stress => 'เครียด/คิดมาก',
        SleepFactor.noise => 'เสียงดัง/แสงรบกวน',
        SleepFactor.lateExercise => 'ออกกำลังกายดึก',
      };

  /// คำแนะนำสั้น ๆ ที่โชว์เมื่อปัจจัยนี้โผล่บ่อยในสัปดาห์
  String get advice => switch (this) {
        SleepFactor.caffeine => 'เลี่ยงกาแฟ/ชาหลังบ่าย 2 โมง',
        SleepFactor.lateMeal => 'กินมื้อสุดท้ายก่อนนอนอย่างน้อย 3 ชั่วโมง',
        SleepFactor.screen => 'วางมือถือก่อนนอน 30 นาที',
        SleepFactor.alcohol => 'แอลกอฮอล์ทำให้หลับตื้นและตื่นกลางดึก',
        SleepFactor.stress => 'จดสิ่งที่ค้างใจลงกระดาษก่อนนอน',
        SleepFactor.noise => 'ลองที่อุดหู/ผ้าปิดตา หรือปรับห้องให้มืดสนิท',
        SleepFactor.lateExercise => 'เลี่ยงออกกำลังหนักก่อนนอน 2 ชั่วโมง',
      };
}

/// การนอนหนึ่งคืน — เก็บคืนละหนึ่งรายการโดยใช้ "วันที่ตื่น" (yyyy-MM-dd) เป็น id
/// บันทึกซ้ำของคืนเดิมจึงทับรายการเดิมเสมอ (แบบเดียวกับ [WaterLog])
class SleepEntry {
  final String id; // = dateKey ของวันที่ตื่น
  /// วันที่ตื่นนอน (ตัดเวลาออกให้เหลือแค่ปี-เดือน-วัน)
  final DateTime date;

  /// "HH:mm" เติมศูนย์ข้างหน้า — เวลาเข้านอนและเวลาตื่น
  final String bedTime;
  final String wakeTime;

  final SleepQuality quality;

  /// จำนวนครั้งที่ตื่นกลางดึก
  final int awakenings;

  final List<SleepFactor> factors;
  final String? note;

  SleepEntry({
    required DateTime date,
    required this.bedTime,
    required this.wakeTime,
    this.quality = SleepQuality.good,
    this.awakenings = 0,
    this.factors = const [],
    this.note,
  })  : id = MealEntry.dateKeyOf(date),
        date = DateTime(date.year, date.month, date.day);

  /// นาทีนับจากเที่ยงคืนของ "HH:mm" — คืน null ถ้าอ่านไม่ออก
  static int? minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  /// ระยะเวลาที่นอนเป็นนาที — วนข้ามเที่ยงคืนให้เอง (เข้านอน 23:00 ตื่น 06:30 = 450)
  int get durationMinutes {
    final bed = minutesOf(bedTime);
    final wake = minutesOf(wakeTime);
    if (bed == null || wake == null) return 0;
    return (wake - bed + 1440) % 1440;
  }

  /// วันที่ "เข้านอน" — ถ้าเข้านอนช่วงเย็น/ค่ำจะเป็นวันก่อนหน้าวันที่ตื่น
  /// ใช้แสดงผลว่า "คืนวันอังคาร" แทนที่จะพูดถึงวันที่ตื่นซึ่งเข้าใจยากกว่า
  DateTime get nightDate {
    final bed = minutesOf(bedTime);
    // เข้านอนตั้งแต่เที่ยงวันเป็นต้นไป = หลับข้ามคืนมาตื่นวันถัดไป
    if (bed != null && bed >= 12 * 60) return date.subtract(const Duration(days: 1));
    return date;
  }

  String get dateKey => id;

  bool isOnDay(DateTime day) => id == MealEntry.dateKeyOf(day);

  SleepEntry copyWith({
    DateTime? date,
    String? bedTime,
    String? wakeTime,
    SleepQuality? quality,
    int? awakenings,
    List<SleepFactor>? factors,
    String? note,
  }) =>
      SleepEntry(
        date: date ?? this.date,
        bedTime: bedTime ?? this.bedTime,
        wakeTime: wakeTime ?? this.wakeTime,
        quality: quality ?? this.quality,
        awakenings: awakenings ?? this.awakenings,
        factors: factors ?? this.factors,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'bedTime': bedTime,
        'wakeTime': wakeTime,
        'quality': quality.name,
        'awakenings': awakenings,
        'factors': factors.map((f) => f.name).toList(),
        'note': note,
      };

  factory SleepEntry.fromMap(Map<String, dynamic> map) => SleepEntry(
        date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
        bedTime: map['bedTime'] as String? ?? '23:00',
        wakeTime: map['wakeTime'] as String? ?? '07:00',
        quality: SleepQuality.values.firstWhere(
          (q) => q.name == map['quality'],
          orElse: () => SleepQuality.good,
        ),
        awakenings: (map['awakenings'] as num?)?.toInt() ?? 0,
        factors: ((map['factors'] as List?) ?? const [])
            .expand<SleepFactor>((name) => SleepFactor.values.where((f) => f.name == name))
            .toList(),
        note: map['note'] as String?,
      );
}

/// สรุปการนอนของช่วงหนึ่ง (ปกติคือ 7 คืนล่าสุด)
class SleepStats {
  final int nightCount;

  /// ค่าเฉลี่ยของระยะเวลานอนเป็นนาที
  final double averageMinutes;

  /// ค่าเฉลี่ยน้ำหนักคุณภาพ 0–1
  final double averageQuality;

  final double averageAwakenings;

  /// ความสม่ำเสมอของเวลาเข้านอน 0–1 (1 = เข้านอนเวลาเดิมทุกคืน)
  final double bedtimeConsistency;

  /// ปัจจัยรบกวนที่พบบ่อยที่สุด เรียงจากมากไปน้อย
  final List<SleepFactor> commonFactors;

  const SleepStats({
    this.nightCount = 0,
    this.averageMinutes = 0,
    this.averageQuality = 0,
    this.averageAwakenings = 0,
    this.bedtimeConsistency = 0,
    this.commonFactors = const [],
  });

  bool get isEmpty => nightCount == 0;

  factory SleepStats.of(Iterable<SleepEntry> nights) {
    final list = nights.toList();
    if (list.isEmpty) return const SleepStats();

    var minutes = 0.0, quality = 0.0, awakenings = 0.0;
    final factorCounts = <SleepFactor, int>{};
    // เวลาเข้านอนหลังเที่ยงคืน (เช่น 01:30) ต้องนับเป็น "ดึกกว่า" 23:00 ไม่ใช่เช้ากว่า
    // จึงบวก 24 ชั่วโมงให้ก่อนหาค่าเฉลี่ย ไม่งั้นความสม่ำเสมอจะเพี้ยนไปคนละโลก
    final bedMinutes = <int>[];

    for (final n in list) {
      minutes += n.durationMinutes;
      quality += n.quality.weight;
      awakenings += n.awakenings;
      for (final f in n.factors) {
        factorCounts[f] = (factorCounts[f] ?? 0) + 1;
      }
      final bed = SleepEntry.minutesOf(n.bedTime);
      if (bed != null) bedMinutes.add(bed < 12 * 60 ? bed + 1440 : bed);
    }

    final sorted = factorCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SleepStats(
      nightCount: list.length,
      averageMinutes: minutes / list.length,
      averageQuality: quality / list.length,
      averageAwakenings: awakenings / list.length,
      bedtimeConsistency: _consistencyOf(bedMinutes),
      commonFactors: sorted.map((e) => e.key).toList(),
    );
  }

  /// แปลงความเหวี่ยงของเวลาเข้านอนเป็นคะแนน 0–1
  /// เหวี่ยงเฉลี่ย 0 นาที = 1.0, เหวี่ยง 90 นาทีขึ้นไป = 0.0
  static double _consistencyOf(List<int> bedMinutes) {
    if (bedMinutes.length < 2) return bedMinutes.isEmpty ? 0 : 1;
    final mean = bedMinutes.reduce((a, b) => a + b) / bedMinutes.length;
    final deviation =
        bedMinutes.fold<double>(0, (sum, m) => sum + (m - mean).abs()) / bedMinutes.length;
    return (1 - deviation / 90).clamp(0, 1).toDouble();
  }
}
