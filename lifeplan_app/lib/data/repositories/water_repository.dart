import 'package:hive_flutter/hive_flutter.dart';

import '../../models/meal_entry.dart';
import '../../models/water_log.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';

class WaterRepository extends HiveRepository<WaterLog> {
  WaterRepository()
      : super(
          box: Hive.box<Map>(HiveBoxes.waterLogs),
          fromMap: WaterLog.fromMap,
          toMap: (w) => w.toMap(),
          idOf: (w) => w.id,
        );

  /// บันทึกของวันที่ระบุ — ยังไม่เคยดื่ม/ยังไม่เคยบันทึก = 0 มล.
  WaterLog getForDay(DateTime day) {
    final map = box.get(MealEntry.dateKeyOf(day));
    if (map == null) return WaterLog(date: day);
    return WaterLog.fromMap(Map<String, dynamic>.from(map));
  }

  WaterLog getToday() => getForDay(DateTime.now());

  /// เพิ่ม/ลดปริมาณน้ำของวันนั้น (ติดลบได้ แต่ยอดรวมไม่ต่ำกว่า 0)
  Future<WaterLog> addMilliliters(int ml, {DateTime? day}) async {
    final target = day ?? DateTime.now();
    final current = getForDay(target);
    final updated = current.copyWith(milliliters: (current.milliliters + ml).clamp(0, 100000));
    await put(updated);
    return updated;
  }

  Future<WaterLog> addGlass({DateTime? day}) => addMilliliters(WaterLog.glassMl, day: day);

  Future<WaterLog> removeGlass({DateTime? day}) => addMilliliters(-WaterLog.glassMl, day: day);
}
