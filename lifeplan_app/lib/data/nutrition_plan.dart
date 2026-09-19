import '../models/body_profile.dart';
import '../models/goal_settings.dart';

/// เป้าหมายโภชนาการที่คำนวณจากร่างกายและกิจกรรมของผู้ใช้
class NutritionPlan {
  /// พลังงานที่ร่างกายใช้ตอนพัก (kcal/วัน)
  final int bmr;

  /// พลังงานที่ใช้จริงทั้งวันรวมกิจกรรม (kcal/วัน)
  final int tdee;

  /// พลังงานเป้าหมายหลังปรับตามเป้าหมายน้ำหนัก
  final int calorieTarget;

  final double proteinTarget;
  final double carbTarget;
  final double fatTarget;
  final double sugarLimit;
  final int waterTargetMl;

  final double bmi;

  /// คำแนะนำสั้น ๆ จากตัวเลขของผู้ใช้เอง
  final List<String> advice;

  const NutritionPlan({
    required this.bmr,
    required this.tdee,
    required this.calorieTarget,
    required this.proteinTarget,
    required this.carbTarget,
    required this.fatTarget,
    required this.sugarLimit,
    required this.waterTargetMl,
    required this.bmi,
    this.advice = const [],
  });

  /// แปลผล BMI ตามเกณฑ์เอเชีย (คนไทยเสี่ยงโรคที่ BMI ต่ำกว่าเกณฑ์สากล)
  String get bmiLabel {
    if (bmi < 18.5) return 'ผอมกว่าเกณฑ์';
    if (bmi < 23) return 'สมส่วน';
    if (bmi < 25) return 'ท้วม';
    if (bmi < 30) return 'อ้วนระดับ 1';
    return 'อ้วนระดับ 2';
  }

  /// เอาไปใช้เป็นเป้าหมายในแอป (ทับเฉพาะส่วนโภชนาการ ไม่ยุ่งกับเป้าเงิน/ขาย/นอน)
  GoalSettings applyTo(GoalSettings current) => current.copyWith(
        calorieTarget: calorieTarget,
        proteinTarget: proteinTarget,
        carbTarget: carbTarget,
        fatTarget: fatTarget,
        sugarLimit: sugarLimit,
        waterTargetMl: waterTargetMl,
      );
}

/// คำนวณเป้าหมายโภชนาการเฉพาะบุคคล — เป็นฟังก์ชันล้วน ไม่แตะ Hive จึงเทสต์ได้ตรง ๆ
///
/// **สูตรที่ใช้และเหตุผล**
/// - พลังงานพื้นฐาน: Mifflin-St Jeor (แม่นกว่า Harris-Benedict ในคนทั่วไป)
/// - โปรตีน: 1.2–2.0 ก./กก. ตามระดับกิจกรรม (ยิ่งออกกำลังกายหนักยิ่งต้องการมาก)
/// - ไขมัน 25% ของพลังงาน, น้ำตาลไม่เกิน 10% (เกณฑ์ WHO), ที่เหลือเป็นคาร์โบไฮเดรต
/// - น้ำ: 35 มล./กก. + ชดเชยการออกกำลังกาย 500 มล. ต่อครึ่งชั่วโมง
///
/// **ไม่ใช่คำแนะนำทางการแพทย์** — คนที่มีโรคประจำตัว ตั้งครรภ์ หรือคุมอาหารเฉพาะทาง
/// ควรใช้ตัวเลขจากแพทย์/นักกำหนดอาหารแทน
class NutritionPlanner {
  NutritionPlanner._();

  /// น้ำต่อน้ำหนักตัว 1 กก. (มล.)
  static const waterMlPerKg = 35;

  /// น้ำชดเชยต่อการออกกำลังกาย 30 นาที (มล.)
  static const waterMlPer30MinExercise = 500;

  static NutritionPlan? of(
    BodyProfile profile, {
    int weeklyExerciseMinutes = 0,
    DateTime? now,
  }) {
    final age = profile.age(now: now);
    final height = profile.heightCm;
    final weight = profile.weightKg;
    if (age == null || height == null || weight == null) return null;
    if (age <= 0 || height <= 0 || weight <= 0) return null;

    // Mifflin-St Jeor
    final base = 10 * weight + 6.25 * height - 5 * age;
    final bmr = profile.sex == BodySex.male ? base + 5 : base - 161;
    final tdee = bmr * profile.activityLevel.factor;
    final calories = tdee * profile.weightGoal.calorieFactor;

    final proteinPerKg = switch (profile.activityLevel) {
      ActivityLevel.sedentary => 1.2,
      ActivityLevel.light => 1.4,
      ActivityLevel.moderate => 1.6,
      ActivityLevel.active => 1.8,
      ActivityLevel.veryActive => 2.0,
    };
    final protein = weight * proteinPerKg;
    final fat = calories * 0.25 / 9;
    // ที่เหลือหลังหักโปรตีนกับไขมันเป็นคาร์บ — กันติดลบเมื่อเป้าพลังงานต่ำมาก
    final carbs = ((calories - protein * 4 - fat * 9) / 4).clamp(50.0, 1000.0);
    final sugar = calories * 0.10 / 4;

    final exerciseWater = (weeklyExerciseMinutes / 7 / 30 * waterMlPer30MinExercise).round();
    final water = (weight * waterMlPerKg).round() + exerciseWater;

    final bmi = weight / ((height / 100) * (height / 100));

    return NutritionPlan(
      bmr: bmr.round(),
      tdee: tdee.round(),
      calorieTarget: calories.round(),
      proteinTarget: _round1(protein),
      carbTarget: _round1(carbs),
      fatTarget: _round1(fat),
      sugarLimit: _round1(sugar),
      // ปัดขึ้นเป็นหลักร้อยให้จำง่ายเวลานับเป็นแก้ว
      waterTargetMl: ((water / 100).ceil() * 100),
      bmi: double.parse(bmi.toStringAsFixed(1)),
      advice: _adviceFor(
        profile: profile,
        bmi: bmi,
        protein: protein,
        weeklyExerciseMinutes: weeklyExerciseMinutes,
        calories: calories,
      ),
    );
  }

  static List<String> _adviceFor({
    required BodyProfile profile,
    required double bmi,
    required double protein,
    required int weeklyExerciseMinutes,
    required double calories,
  }) {
    final tips = <String>[];

    if (bmi < 18.5) {
      tips.add('BMI ต่ำกว่าเกณฑ์ — เพิ่มพลังงานจากอาหารที่มีคุณค่า (ถั่ว ไข่ นม ข้าวกล้อง) แทนของทอด/ของหวาน');
    } else if (bmi >= 23) {
      tips.add('BMI อยู่เกณฑ์ท้วมขึ้นไป — ลดน้ำตาลกับของทอดก่อน แล้วค่อยลดปริมาณข้าว จะหิวน้อยกว่าการอดทั้งมื้อ');
    }

    tips.add('โปรตีนเป้าหมาย ${protein.round()} ก./วัน ≈ อกไก่ ${(protein / 31).ceil()} ชิ้น (100 ก.) '
        'หรือไข่ ${(protein / 6).ceil()} ฟอง — แบ่งให้ครบทุกมื้อดูดซึมได้ดีกว่ากินรวดเดียว');

    // 150 นาที/สัปดาห์ คือเกณฑ์ขั้นต่ำขององค์การอนามัยโลก
    if (weeklyExerciseMinutes > 0 && weeklyExerciseMinutes < 150) {
      tips.add('สัปดาห์นี้ออกกำลังกาย $weeklyExerciseMinutes นาที — ยังไม่ถึง 150 นาทีตามเกณฑ์ WHO '
          'เพิ่มอีกสัปดาห์ละ 2–3 ครั้ง ครั้งละ 20–30 นาทีก็ถึงแล้ว');
    } else if (weeklyExerciseMinutes >= 150) {
      tips.add('ออกกำลังกาย $weeklyExerciseMinutes นาที/สัปดาห์ ถึงเกณฑ์ WHO แล้ว '
          'อย่าลืมดื่มน้ำชดเชยระหว่างและหลังออกกำลังกาย');
    }

    final typical = profile.activityLevel.typicalWeeklyMinutes;
    if (weeklyExerciseMinutes > 0 && typical > 0 && weeklyExerciseMinutes < typical * 0.5) {
      tips.add('ระดับกิจกรรมที่เลือกไว้ดูสูงกว่าที่บันทึกจริง — ถ้าเลือกสูงเกิน เป้าพลังงานจะมากเกินความต้องการ');
    }

    if (profile.weightGoal == WeightGoal.lose) {
      tips.add('เป้าพลังงาน ${calories.round()} kcal ต่ำกว่าที่ร่างกายใช้ราว 15% — ลดได้ราว 0.5 กก./สัปดาห์ '
          'ถ้าน้ำหนักไม่ขยับ 2 สัปดาห์ค่อยปรับลงอีกเล็กน้อย');
    } else if (profile.weightGoal == WeightGoal.gain) {
      tips.add('ช่วงเพิ่มน้ำหนักควรมาพร้อมเวทเทรนนิ่ง ไม่งั้นน้ำหนักที่ขึ้นจะเป็นไขมันมากกว่ากล้ามเนื้อ');
    }

    return tips;
  }

  static double _round1(double value) => double.parse(value.toStringAsFixed(1));
}
