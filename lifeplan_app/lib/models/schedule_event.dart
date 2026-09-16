import '../models/life_category.dart';

class ScheduleEvent {
  final String id;
  final String time; // "HH:mm", zero-padded so string-sort == time-sort
  final int weekday; // 1 = จันทร์ ... 7 = อาทิตย์ (ตรงกับ DateTime.weekday)
  final String title;
  final String? subtitle;
  final LifeCategory category;

  /// กิจกรรมที่คัดลอกไปหลายวันจะมี seriesId เดียวกัน เพื่อให้แก้/ลบพร้อมกันทุกวันได้
  /// (null = รายการเดี่ยวหรือรายการต้นฉบับรุ่นเก่า ใช้ [seriesKey] แทนเสมอ)
  final String? seriesId;

  const ScheduleEvent({
    required this.id,
    required this.time,
    this.weekday = DateTime.monday,
    required this.title,
    this.subtitle,
    required this.category,
    this.seriesId,
  });

  /// คีย์ของชุดกิจกรรม — ต้นฉบับที่ยังไม่มี seriesId ใช้ id ตัวเอง
  /// สำเนาที่คัดลอกจากมันจึงได้ seriesId = id ของต้นฉบับ โดยไม่ต้องแก้ต้นฉบับ
  String get seriesKey => seriesId ?? id;

  ScheduleEvent copyWith({
    String? id,
    String? time,
    int? weekday,
    String? title,
    String? subtitle,
    bool clearSubtitle = false,
    LifeCategory? category,
    String? seriesId,
  }) =>
      ScheduleEvent(
        id: id ?? this.id,
        time: time ?? this.time,
        weekday: weekday ?? this.weekday,
        title: title ?? this.title,
        subtitle: clearSubtitle ? null : (subtitle ?? this.subtitle),
        category: category ?? this.category,
        seriesId: seriesId ?? this.seriesId,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'time': time,
        'weekday': weekday,
        'title': title,
        'subtitle': subtitle,
        'category': category.name,
        'seriesId': seriesId,
      };

  factory ScheduleEvent.fromMap(Map<String, dynamic> map) => ScheduleEvent(
        id: map['id'] as String,
        time: map['time'] as String,
        // กิจกรรมที่บันทึกไว้ก่อนมีมุมมองรายสัปดาห์ยังไม่มี weekday — ให้ไปอยู่วันจันทร์
        weekday: map['weekday'] as int? ?? DateTime.monday,
        title: map['title'] as String,
        subtitle: map['subtitle'] as String?,
        category: LifeCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => LifeCategory.work),
        seriesId: map['seriesId'] as String?,
      );
}
