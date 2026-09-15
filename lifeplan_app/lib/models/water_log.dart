import 'meal_entry.dart';

/// ปริมาณน้ำที่ดื่มของหนึ่งวัน — เก็บวันละหนึ่งรายการ โดยใช้คีย์ yyyy-MM-dd
/// เป็น id เพื่อให้บันทึกซ้ำของวันเดิมทับรายการเดิมเสมอ
class WaterLog {
  /// ปริมาณต่อ 1 แก้วที่ใช้ทั่วทั้งแอป
  static const glassMl = 250;

  final String id; // = dateKey
  final DateTime date;
  final int milliliters;

  WaterLog({
    required DateTime date,
    this.milliliters = 0,
  })  : id = MealEntry.dateKeyOf(date),
        date = DateTime(date.year, date.month, date.day);

  int get glasses => (milliliters / glassMl).floor();

  WaterLog copyWith({int? milliliters}) => WaterLog(
        date: date,
        milliliters: milliliters ?? this.milliliters,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'milliliters': milliliters,
      };

  factory WaterLog.fromMap(Map<String, dynamic> map) => WaterLog(
        date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
        milliliters: (map['milliliters'] as num?)?.toInt() ?? 0,
      );
}
