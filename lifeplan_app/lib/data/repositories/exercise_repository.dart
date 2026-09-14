import 'package:hive_flutter/hive_flutter.dart';

import '../../models/exercise_item.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';

class ExerciseRepository extends HiveRepository<ExercisePlanItem> {
  ExerciseRepository()
      : super(
          box: Hive.box<Map>(HiveBoxes.exerciseItems),
          fromMap: ExercisePlanItem.fromMap,
          toMap: (t) => t.toMap(),
          idOf: (t) => t.id,
        );
}
