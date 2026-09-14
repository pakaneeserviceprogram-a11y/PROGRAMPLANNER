import 'package:hive_flutter/hive_flutter.dart';

import '../../models/work_task.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';

class WorkTaskRepository extends HiveRepository<WorkTask> {
  WorkTaskRepository()
      : super(
          box: Hive.box<Map>(HiveBoxes.workTasks),
          fromMap: WorkTask.fromMap,
          toMap: (t) => t.toMap(),
          idOf: (t) => t.id,
        );
}
