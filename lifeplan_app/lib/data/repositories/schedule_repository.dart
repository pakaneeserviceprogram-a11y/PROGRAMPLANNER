import 'package:hive_flutter/hive_flutter.dart';

import '../../models/schedule_event.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';

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
}
