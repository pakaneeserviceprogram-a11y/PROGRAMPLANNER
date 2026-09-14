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
    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }
}
