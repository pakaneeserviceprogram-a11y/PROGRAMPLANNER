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

  /// นัดหมายเฉพาะวันที่ (เก็บแค่วัน ไม่มีเวลา) — null = กิจกรรมประจำสัปดาห์ที่วนซ้ำทุกสัปดาห์
  ///
  /// ถ้ามีค่า [weekday] ต้องตรงกับ `date.weekday` เสมอ (ใช้ [ScheduleEvent.oneOff] สร้าง)
  final DateTime? date;

  /// นัดหมายที่สร้างจากหน้าลูกค้า — id ของ `Client` ที่นัด (null = กิจกรรมทั่วไป)
  ///
  /// ผูกด้วย id ไม่ใช่ชื่อ เพราะผู้ใช้เปลี่ยนชื่อลูกค้าได้ (ตรงกับ `linkedEntityId` ใน DATA_MODEL)
  final String? clientId;

  const ScheduleEvent({
    required this.id,
    required this.time,
    this.weekday = DateTime.monday,
    required this.title,
    this.subtitle,
    required this.category,
    this.seriesId,
    this.date,
    this.clientId,
  });

  /// นัดหมายครั้งเดียวในวันที่ [date] — ตั้ง weekday ให้ตรงกับวันที่ให้เอง
  factory ScheduleEvent.oneOff({
    required String id,
    required String time,
    required DateTime date,
    required String title,
    String? subtitle,
    required LifeCategory category,
    String? clientId,
  }) =>
      ScheduleEvent(
        id: id,
        time: time,
        weekday: date.weekday,
        title: title,
        subtitle: subtitle,
        category: category,
        date: DateTime(date.year, date.month, date.day),
        clientId: clientId,
      );

  bool get isOneOff => date != null;

  /// กิจกรรมนี้เกิดขึ้นในวัน [day] หรือไม่ (ประจำสัปดาห์ = ตรงวันในสัปดาห์, เฉพาะวันที่ = ตรงวันที่)
  bool occursOn(DateTime day) {
    final d = date;
    if (d == null) return weekday == day.weekday;
    return d.year == day.year && d.month == day.month && d.day == day.day;
  }

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
    DateTime? date,
    bool clearDate = false,
    String? clientId,
  }) =>
      ScheduleEvent(
        id: id ?? this.id,
        time: time ?? this.time,
        weekday: weekday ?? this.weekday,
        title: title ?? this.title,
        subtitle: clearSubtitle ? null : (subtitle ?? this.subtitle),
        category: category ?? this.category,
        seriesId: seriesId ?? this.seriesId,
        date: clearDate ? null : (date ?? this.date),
        clientId: clientId ?? this.clientId,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'time': time,
        'weekday': weekday,
        'title': title,
        'subtitle': subtitle,
        'category': category.name,
        'seriesId': seriesId,
        'date': date == null ? null : _dateKey(date!),
        'clientId': clientId,
      };

  /// "yyyy-MM-dd" — เก็บเป็นวันล้วน ไม่มีโซนเวลามาทำให้วันเลื่อน
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  factory ScheduleEvent.fromMap(Map<String, dynamic> map) {
    final date = _parseDate(map['date']);
    return ScheduleEvent(
      id: map['id'] as String,
      time: map['time'] as String,
      // กิจกรรมที่บันทึกไว้ก่อนมีมุมมองรายสัปดาห์ยังไม่มี weekday — ให้ไปอยู่วันจันทร์
      // นัดหมายเฉพาะวันที่ยึดวันในสัปดาห์จากวันที่เสมอ กันข้อมูลไม่ตรงกัน
      weekday: date?.weekday ?? map['weekday'] as int? ?? DateTime.monday,
      title: map['title'] as String,
      subtitle: map['subtitle'] as String?,
      category: LifeCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => LifeCategory.work),
      seriesId: map['seriesId'] as String?,
      date: date,
      clientId: map['clientId'] as String?,
    );
  }
}
