import 'package:hive_flutter/hive_flutter.dart';

import '../../models/meal_entry.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';

class MealRepository extends HiveRepository<MealEntry> {
  MealRepository()
      : super(
          box: Hive.box<Map>(HiveBoxes.mealEntries),
          fromMap: MealEntry.fromMap,
          toMap: (m) => m.toMap(),
          idOf: (m) => m.id,
        );

  /// มื้ออาหารของวันที่ระบุ เรียงตามเวลา ("HH:mm" เรียงเป็นสตริงได้เลย)
  List<MealEntry> getForDay(DateTime day) {
    final items = getAll().where((m) => m.isOnDay(day)).toList();
    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }

  List<MealEntry> getToday() => getForDay(DateTime.now());

  NutritionTotals totalsForDay(DateTime day) => NutritionTotals.of(getForDay(day));
}
