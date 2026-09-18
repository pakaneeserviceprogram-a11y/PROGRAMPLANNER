import '../models/meal_entry.dart';
import '../models/sleep_entry.dart';
import 'insights.dart';
import 'repositories/meal_repository.dart';

/// ผลเทียบ "คืนที่มีพฤติกรรมนี้" กับ "คืนที่ไม่มี"
class SleepComparison {
  /// ชื่อพฤติกรรม เช่น "คาเฟอีนหลังบ่าย 2"
  final String label;

  /// คำแนะนำสั้น ๆ เมื่อพบว่าคืนที่มีพฤติกรรมนี้นอนแย่กว่า
  final String advice;

  final int withCount;
  final int withoutCount;

  /// คะแนนการนอนเฉลี่ย 0–100 ของแต่ละกลุ่ม
  final double withScore;
  final double withoutScore;

  const SleepComparison({
    required this.label,
    required this.advice,
    required this.withCount,
    required this.withoutCount,
    required this.withScore,
    required this.withoutScore,
  });

  /// ต่างกันกี่คะแนน (บวก = คืนที่มีพฤติกรรมนี้นอนแย่กว่า)
  double get delta => withoutScore - withScore;

  /// ทั้งสองกลุ่มต้องมีอย่างน้อย 2 คืน ไม่งั้นเป็นการสรุปจากคืนเดียวซึ่งไม่มีความหมาย
  bool get hasEnoughData => withCount >= 2 && withoutCount >= 2;

  /// ต่างกันน้อยกว่า 5 คะแนนถือว่าพอ ๆ กัน ไม่ควรชี้นิ้วว่าเป็นเพราะสิ่งนี้
  bool get isMeaningful => hasEnoughData && delta.abs() >= 5;
}

/// จับคู่สิ่งที่กินกับคุณภาพการนอน — ตอบคำถาม "กาแฟบ่ายหรือมื้อดึกทำให้นอนแย่ไหม"
/// โดยใช้ข้อมูลที่ผู้ใช้บันทึกอยู่แล้ว ไม่ต้องติ๊ก "ปัจจัยรบกวน" เอง
///
/// **ข้อจำกัดที่ตั้งใจ**: แอปไม่ได้เก็บปริมาณคาเฟอีน จึงเดาจาก *ชื่อเมนู* ที่ผู้ใช้พิมพ์
/// (กาแฟ/ชา/โกโก้/น้ำอัดลม) — ถ้าพิมพ์ชื่อแปลก ๆ จะจับไม่ได้ ถือเป็นการช่วยสังเกต
/// ไม่ใช่ข้อสรุปทางการแพทย์
class SleepNutritionInsights {
  SleepNutritionInsights._();

  /// คำที่บ่งชี้ว่าเมนูนั้นน่าจะมีคาเฟอีน (ตัวพิมพ์เล็ก-ใหญ่ไม่สำคัญ)
  static const caffeineKeywords = [
    'กาแฟ', 'ลาเต้', 'ลาเต้', 'อเมริกาโน', 'เอสเปรสโซ', 'เอสเพรสโซ', 'มอคค่า', 'คาปูชิโน',
    'ชาเขียว', 'ชาไทย', 'ชานม', 'ชาดำ', 'ชามะนาว', 'มัทฉะ', 'โกโก้', 'โค้ก', 'เป๊ปซี่',
    'น้ำอัดลม', 'ชูกำลัง', 'คาเฟอีน',
    'coffee', 'espresso', 'latte', 'americano', 'mocha', 'cappuccino', 'matcha', 'cola', 'coke', 'pepsi',
  ];

  /// นับเป็น "คาเฟอีนช่วงบ่าย" ตั้งแต่เวลานี้ (นาทีจากเที่ยงคืน) — คาเฟอีนอยู่ในตัวราว 5–6 ชม.
  static const afternoonFrom = 14 * 60;

  /// มื้อดึก = กินตั้งแต่เวลานี้เป็นต้นไป
  static const lateMealFrom = 20 * 60;

  static int? _minutesOf(String hhmm) => SleepEntry.minutesOf(hhmm);

  static bool isCaffeine(MealEntry meal) {
    final title = meal.title.toLowerCase();
    return caffeineKeywords.any((k) => title.contains(k.toLowerCase()));
  }

  static bool isAfternoonCaffeine(MealEntry meal) {
    if (!isCaffeine(meal)) return false;
    final minutes = _minutesOf(meal.time);
    return minutes != null && minutes >= afternoonFrom;
  }

  static bool isLateMeal(MealEntry meal) {
    final minutes = _minutesOf(meal.time);
    return minutes != null && minutes >= lateMealFrom;
  }

  /// เทียบคะแนนการนอนของคืนที่ "มี" กับ "ไม่มี" พฤติกรรมแต่ละอย่าง
  ///
  /// ดูมื้ออาหารของ **วันที่เข้านอน** (`SleepEntry.nightDate`) ไม่ใช่วันที่ตื่น
  static List<SleepComparison> compare(
    Iterable<SleepEntry> nights,
    MealRepository meals, {
    required int sleepTargetMinutes,
  }) {
    final checks = <({String label, String advice, bool Function(MealEntry) test})>[
      (
        label: 'คาเฟอีนหลังบ่าย 2',
        advice: 'ลองเลื่อนกาแฟ/ชาแก้วสุดท้ายมาก่อนบ่าย 2 แล้วดูว่าดีขึ้นไหม',
        test: isAfternoonCaffeine,
      ),
      (
        label: 'มื้อดึก (หลัง 2 ทุ่ม)',
        advice: 'ลองกินมื้อสุดท้ายให้เสร็จก่อน 2 ทุ่ม หรือให้ห่างจากเวลานอนราว 3 ชม.',
        test: isLateMeal,
      ),
    ];

    final results = <SleepComparison>[];
    for (final check in checks) {
      final withScores = <int>[];
      final withoutScores = <int>[];

      for (final night in nights) {
        final dayMeals = meals.getForDay(night.nightDate);
        // ไม่มีบันทึกมื้ออาหารของวันนั้นเลย = ไม่รู้ว่ากินอะไร ข้ามไปแทนที่จะเดาว่า "ไม่ได้กิน"
        if (dayMeals.isEmpty) continue;

        final score = Insights.scoreOfNight(night, sleepTargetMinutes);
        (dayMeals.any(check.test) ? withScores : withoutScores).add(score);
      }

      results.add(SleepComparison(
        label: check.label,
        advice: check.advice,
        withCount: withScores.length,
        withoutCount: withoutScores.length,
        withScore: _average(withScores),
        withoutScore: _average(withoutScores),
      ));
    }
    return results;
  }

  static double _average(List<int> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
}
