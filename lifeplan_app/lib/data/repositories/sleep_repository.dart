import 'package:hive_flutter/hive_flutter.dart';

import '../../models/meal_entry.dart';
import '../../models/sleep_entry.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';

class SleepRepository extends HiveRepository<SleepEntry> {
  SleepRepository()
      : super(
          box: Hive.box<Map>(HiveBoxes.sleepEntries),
          fromMap: SleepEntry.fromMap,
          toMap: (s) => s.toMap(),
          idOf: (s) => s.id,
        );

  /// การนอนของคืนที่ตื่นในวันนั้น — ยังไม่เคยบันทึก = null
  SleepEntry? getForDay(DateTime day) {
    final map = box.get(MealEntry.dateKeyOf(day));
    if (map == null) return null;
    return SleepEntry.fromMap(Map<String, dynamic>.from(map));
  }

  /// การนอนของเมื่อคืน (บันทึกไว้ใต้วันที่ตื่น = วันนี้)
  SleepEntry? getLastNight() => getForDay(DateTime.now());

  /// ทุกคืนเรียงจากใหม่ไปเก่า
  List<SleepEntry> getAllSorted() {
    final items = getAll();
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  /// [days] คืนล่าสุดนับถอยหลังจาก [until] (รวมวันนั้นด้วย) เรียงจากเก่าไปใหม่
  ///
  /// คืนที่ยังไม่ได้บันทึกจะไม่อยู่ในผลลัพธ์ — ผู้เรียกดูจาก `length` ได้ว่าบันทึกครบไหม
  List<SleepEntry> getRecent({int days = 7, DateTime? until}) {
    final end = until ?? DateTime.now();
    final result = <SleepEntry>[];
    for (var i = days - 1; i >= 0; i--) {
      final entry = getForDay(end.subtract(Duration(days: i)));
      if (entry != null) result.add(entry);
    }
    return result;
  }

  SleepStats statsForRecent({int days = 7, DateTime? until}) =>
      SleepStats.of(getRecent(days: days, until: until));
}
