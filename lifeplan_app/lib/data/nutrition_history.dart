import '../models/meal_entry.dart';
import '../models/water_log.dart';
import 'repositories/meal_repository.dart';
import 'repositories/water_repository.dart';

/// สรุปโภชนาการของหนึ่งวัน (ใช้ในกราฟย้อนหลัง)
class DayNutrition {
  final DateTime date;
  final NutritionTotals totals;
  final int waterMl;

  const DayNutrition({required this.date, required this.totals, required this.waterMl});

  int get glasses => (waterMl / WaterLog.glassMl).floor();

  /// วันที่ยังไม่ได้บันทึกอะไรเลย — ไม่ควรถูกนับเป็น "วันที่กินน้อย"
  bool get isEmpty => totals.mealCount == 0 && waterMl == 0;
}

/// ย้อนหลัง N วันของหน้าโภชนาการ (วันเก่าสุดอยู่หน้า วันนี้อยู่ท้าย)
class NutritionHistory {
  final List<DayNutrition> days;

  const NutritionHistory(this.days);

  factory NutritionHistory.of(
    MealRepository meals,
    WaterRepository water, {
    int days = 7,
    DateTime? today,
  }) {
    final end = today ?? DateTime.now();
    return NutritionHistory([
      for (var i = days - 1; i >= 0; i--)
        () {
          // ลบวันแบบปฏิทิน ไม่ใช้ Duration — กันคลาดในวันเปลี่ยนเวลาออมแสง
          final day = DateTime(end.year, end.month, end.day - i);
          return DayNutrition(
            date: day,
            totals: NutritionTotals.of(meals.getForDay(day)),
            waterMl: water.getForDay(day).milliliters,
          );
        }(),
    ]);
  }

  /// เฉพาะวันที่บันทึกไว้จริง — ค่าเฉลี่ยจะได้ไม่ถูกถ่วงให้ต่ำด้วยวันที่ยังไม่ได้ใช้แอป
  List<DayNutrition> get loggedDays => days.where((d) => !d.isEmpty).toList();

  int get averageCalories {
    final logged = loggedDays;
    if (logged.isEmpty) return 0;
    return (logged.fold<int>(0, (s, d) => s + d.totals.calories) / logged.length).round();
  }

  double get averageWaterGlasses {
    final logged = loggedDays;
    if (logged.isEmpty) return 0;
    return logged.fold<int>(0, (s, d) => s + d.glasses) / logged.length;
  }

  /// จำนวนวันที่พลังงานไม่เกินเป้า (นับเฉพาะวันที่บันทึกไว้)
  int daysWithinCalorieTarget(int target) =>
      loggedDays.where((d) => target <= 0 || d.totals.calories <= target).length;

  int get maxCalories => days.fold<int>(0, (a, d) => d.totals.calories > a ? d.totals.calories : a);
}
