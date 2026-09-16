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

  /// กิจกรรมของวันเดียว (weekday 1 = จันทร์ ... 7 = อาทิตย์) เรียงตามเวลา
  List<ScheduleEvent> getByWeekday(int weekday) {
    final items = getAll().where((e) => e.weekday == weekday).toList();
    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }

  /// ทั้งสัปดาห์: index 0 = จันทร์ ... index 6 = อาทิตย์ แต่ละวันเรียงตามเวลา
  List<List<ScheduleEvent>> getWeek() => List.generate(7, (i) => getByWeekday(i + 1));

  /// ทุกวันในชุดเดียวกับ [event] (รวมตัวมันเอง) เรียงจันทร์ → อาทิตย์
  List<ScheduleEvent> seriesOf(ScheduleEvent event) {
    final key = event.seriesKey;
    final items = getAll().where((e) => e.seriesKey == key).toList();
    items.sort((a, b) => a.weekday != b.weekday ? a.weekday.compareTo(b.weekday) : a.time.compareTo(b.time));
    return items;
  }

  /// วันนั้นมีกิจกรรมชื่อเดียวกัน เวลาเดียวกันอยู่แล้วหรือยัง — กันคัดลอกซ้ำจนรก
  bool _hasSame(List<ScheduleEvent> all, ScheduleEvent source, int weekday) =>
      all.any((e) => e.weekday == weekday && e.time == source.time && e.title == source.title);

  /// คัดลอก [source] ไปวันอื่นเป็นรายการแยก (แก้ทีละวันได้) แต่ผูกชุดเดียวกันไว้
  ///
  /// ข้ามวันของต้นฉบับเองและวันที่มีกิจกรรมเดียวกันอยู่แล้ว — คืนจำนวนที่สร้างจริง
  Future<int> copyToWeekdays(ScheduleEvent source, Iterable<int> weekdays) async {
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
