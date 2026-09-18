import 'package:hive_flutter/hive_flutter.dart';

import '../../models/schedule_event.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';
import '../id_gen.dart';

class ScheduleRepository extends HiveRepository<ScheduleEvent> {
  ScheduleRepository()
      : super(
          box: Hive.box<Map>(HiveBoxes.scheduleEvents),
          fromMap: ScheduleEvent.fromMap,
          toMap: (t) => t.toMap(),
          idOf: (t) => t.id,
        );

  List<ScheduleEvent> getAllSortedByTime() {
    final items = getAll();
    items.sort((a, b) => a.weekday != b.weekday ? a.weekday.compareTo(b.weekday) : a.time.compareTo(b.time));
    return items;
  }

  /// กิจกรรม **ประจำสัปดาห์** ของวันเดียว (weekday 1 = จันทร์ ... 7 = อาทิตย์) เรียงตามเวลา
  ///
  /// ไม่รวมนัดหมายเฉพาะวันที่ — ถ้าต้องการทุกอย่างที่เกิดขึ้นในวันจริงใช้ [getForDate]
  List<ScheduleEvent> getByWeekday(int weekday) {
    final items = getAll().where((e) => !e.isOneOff && e.weekday == weekday).toList();
    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }

  /// ตารางประจำสัปดาห์: index 0 = จันทร์ ... index 6 = อาทิตย์ แต่ละวันเรียงตามเวลา
  List<List<ScheduleEvent>> getWeek() => List.generate(7, (i) => getByWeekday(i + 1));

  /// ทุกกิจกรรมที่เกิดขึ้นในวันที่ [day] (ประจำสัปดาห์ของวันนั้น + นัดหมายเฉพาะวันที่นั้น) เรียงตามเวลา
  List<ScheduleEvent> getForDate(DateTime day) => eventsOn(getAll(), day);

  /// เหมือน [getForDate] แต่กรองจากรายการที่อ่านไว้แล้ว — หน้าปฏิทินเรียกวันละครั้งหลายสิบวัน
  /// จึงไม่ควรอ่าน box ซ้ำทุกช่อง
  static List<ScheduleEvent> eventsOn(Iterable<ScheduleEvent> all, DateTime day) {
    final items = all.where((e) => e.occursOn(day)).toList();
    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }

  /// นัดหมายของลูกค้ารายนี้ที่ยังมาไม่ถึง (รวมวันนี้) เรียงจากใกล้ที่สุด
  List<ScheduleEvent> upcomingForClient(String clientId, {DateTime? from}) {
    final today = from ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final items = getAll()
        .where((e) => e.clientId == clientId && e.date != null && !e.date!.isBefore(start))
        .toList();
    items.sort((a, b) => a.date! != b.date! ? a.date!.compareTo(b.date!) : a.time.compareTo(b.time));
    return items;
  }

  /// นัดถัดไปของลูกค้ารายนี้ — ยังไม่มีนัด = null
  ScheduleEvent? nextForClient(String clientId, {DateTime? from}) {
    final items = upcomingForClient(clientId, from: from);
    return items.isEmpty ? null : items.first;
  }

  /// ทุกวันในชุดเดียวกับ [event] (รวมตัวมันเอง) เรียงจันทร์ → อาทิตย์
  ///
  /// นัดหมายเฉพาะวันที่ไม่มีชุด คืนแค่ตัวมันเอง
  List<ScheduleEvent> seriesOf(ScheduleEvent event) {
    if (event.isOneOff) return [event];
    final key = event.seriesKey;
    final items = getAll().where((e) => !e.isOneOff && e.seriesKey == key).toList();
    items.sort((a, b) => a.weekday != b.weekday ? a.weekday.compareTo(b.weekday) : a.time.compareTo(b.time));
    return items;
  }

  /// วันนั้นมีกิจกรรมชื่อเดียวกัน เวลาเดียวกันอยู่แล้วหรือยัง — กันคัดลอกซ้ำจนรก
  bool _hasSame(List<ScheduleEvent> all, ScheduleEvent source, int weekday) =>
      all.any((e) => !e.isOneOff && e.weekday == weekday && e.time == source.time && e.title == source.title);

  /// คัดลอก [source] ไปวันอื่นเป็นรายการแยก (แก้ทีละวันได้) แต่ผูกชุดเดียวกันไว้
  ///
  /// ข้ามวันของต้นฉบับเองและวันที่มีกิจกรรมเดียวกันอยู่แล้ว — คืนจำนวนที่สร้างจริง
  Future<int> copyToWeekdays(ScheduleEvent source, Iterable<int> weekdays) async {
    // นัดหมายเฉพาะวันที่คัดลอกเป็นรายสัปดาห์ไม่ได้ (จะกลายเป็นนัดทุกสัปดาห์โดยไม่ตั้งใจ)
    if (source.isOneOff) return 0;
    final all = getAll();
    var created = 0;
    for (final day in weekdays.toSet()) {
      if (day == source.weekday || _hasSame(all, source, day)) continue;
      final copy = source.copyWith(id: newId(), weekday: day, seriesId: source.seriesKey);
      await put(copy);
      all.add(copy);
      created++;
    }
    return created;
  }

  /// คัดลอกกิจกรรมทั้งวัน [fromWeekday] ไปยังวันอื่น ๆ — คืนจำนวนรายการที่สร้างจริง
  Future<int> copyDay(int fromWeekday, Iterable<int> toWeekdays) async {
    var created = 0;
    for (final event in getByWeekday(fromWeekday)) {
      created += await copyToWeekdays(event, toWeekdays);
    }
    return created;
  }

  /// นำชื่อ/เวลา/หมวด/รายละเอียดของ [edited] ไปใช้กับทุกวันในชุด (วันของแต่ละรายการคงเดิม)
  ///
  /// คืนจำนวนรายการที่อัปเดต
  Future<int> updateSeries(ScheduleEvent edited) async {
    final members = seriesOf(edited);
    for (final e in members) {
      await put(ScheduleEvent(
        id: e.id,
        time: edited.time,
        weekday: e.id == edited.id ? edited.weekday : e.weekday,
        title: edited.title,
        subtitle: edited.subtitle,
        category: edited.category,
        seriesId: e.seriesId,
      ));
    }
    return members.length;
  }

  /// ลบทุกวันในชุดของ [event] — คืนจำนวนที่ลบ
  Future<int> deleteSeries(ScheduleEvent event) async {
    final members = seriesOf(event);
    await box.deleteAll(members.map((e) => e.id));
    return members.length;
  }
}
