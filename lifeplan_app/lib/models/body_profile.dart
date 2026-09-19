/// เพศตามที่ใช้ในสูตรคำนวณพลังงาน (Mifflin-St Jeor ใช้ค่าคงที่ต่างกัน)
enum BodySex { male, female }

/// ระดับกิจกรรมต่อวัน — ตัวคูณมาตรฐานของ TDEE
enum ActivityLevel { sedentary, light, moderate, active, veryActive }

/// เป้าหมายน้ำหนัก — ปรับพลังงานขึ้น/ลงจากค่าที่ร่างกายใช้จริง
enum WeightGoal { lose, maintain, gain }

extension BodySexX on BodySex {
  String get label => this == BodySex.male ? 'ชาย' : 'หญิง';
}

extension ActivityLevelX on ActivityLevel {
  String get label => switch (this) {
        ActivityLevel.sedentary => 'นั่งทำงานเป็นหลัก',
        ActivityLevel.light => 'ออกกำลังกายเบา 1–3 วัน/สัปดาห์',
        ActivityLevel.moderate => 'ออกกำลังกายปานกลาง 3–5 วัน/สัปดาห์',
        ActivityLevel.active => 'ออกกำลังกายหนัก 6–7 วัน/สัปดาห์',
        ActivityLevel.veryActive => 'ใช้แรงงานหนัก / ซ้อมวันละ 2 รอบ',
      };

  /// ตัวคูณ TDEE มาตรฐาน (Harris-Benedict activity factor)
  double get factor => switch (this) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
        ActivityLevel.veryActive => 1.9,
      };

  /// นาทีออกกำลังกายต่อสัปดาห์โดยประมาณของระดับนี้ — ใช้เทียบกับที่บันทึกไว้จริง
  int get typicalWeeklyMinutes => switch (this) {
        ActivityLevel.sedentary => 0,
        ActivityLevel.light => 90,
        ActivityLevel.moderate => 200,
        ActivityLevel.active => 350,
        ActivityLevel.veryActive => 500,
      };
}

extension WeightGoalX on WeightGoal {
  String get label => switch (this) {
        WeightGoal.lose => 'ลดน้ำหนัก',
        WeightGoal.maintain => 'คงน้ำหนัก',
        WeightGoal.gain => 'เพิ่มน้ำหนัก/กล้ามเนื้อ',
      };

  /// ปรับพลังงานกี่เปอร์เซ็นต์จาก TDEE — ลด 15% / เพิ่ม 10% เป็นช่วงที่ยั่งยืน
  /// (ลดมากกว่านี้มักทำให้กล้ามเนื้อหายและกลับมากินชดเชย)
  double get calorieFactor => switch (this) {
        WeightGoal.lose => 0.85,
        WeightGoal.maintain => 1.0,
        WeightGoal.gain => 1.1,
      };
}

/// ข้อมูลร่างกายที่ผู้ใช้กรอกเอง ใช้คำนวณเป้าหมายโภชนาการเฉพาะบุคคล
///
/// ยังไม่กรอก = `isComplete` เป็น false แล้วหน้าจอจะชวนให้กรอกก่อน
class BodyProfile {
  final BodySex sex;

  /// ปีเกิดเป็น ค.ศ. — เก็บปีเกิดแทนอายุ เพื่อให้อายุขยับเองทุกปีโดยไม่ต้องแก้
  final int? birthYear;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel activityLevel;
  final WeightGoal weightGoal;

  const BodyProfile({
    this.sex = BodySex.male,
    this.birthYear,
    this.heightCm,
    this.weightKg,
    this.activityLevel = ActivityLevel.light,
    this.weightGoal = WeightGoal.maintain,
  });

  bool get isComplete => birthYear != null && heightCm != null && weightKg != null;

  /// อายุปีเต็มโดยประมาณ (ไม่ได้เก็บวันเกิด จึงคิดจากปีอย่างเดียว)
  int? age({DateTime? now}) {
    if (birthYear == null) return null;
    return (now ?? DateTime.now()).year - birthYear!;
  }

  BodyProfile copyWith({
    BodySex? sex,
    int? birthYear,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activityLevel,
    WeightGoal? weightGoal,
  }) =>
      BodyProfile(
        sex: sex ?? this.sex,
        birthYear: birthYear ?? this.birthYear,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activityLevel: activityLevel ?? this.activityLevel,
        weightGoal: weightGoal ?? this.weightGoal,
      );

  Map<String, dynamic> toMap() => {
        'sex': sex.name,
        'birthYear': birthYear,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activityLevel': activityLevel.name,
        'weightGoal': weightGoal.name,
      };

  factory BodyProfile.fromMap(Map<String, dynamic> map) => BodyProfile(
        sex: BodySex.values.firstWhere((e) => e.name == map['sex'], orElse: () => BodySex.male),
        birthYear: (map['birthYear'] as num?)?.toInt(),
        heightCm: (map['heightCm'] as num?)?.toDouble(),
        weightKg: (map['weightKg'] as num?)?.toDouble(),
        activityLevel: ActivityLevel.values.firstWhere(
          (e) => e.name == map['activityLevel'],
          orElse: () => ActivityLevel.light,
        ),
        weightGoal: WeightGoal.values.firstWhere(
          (e) => e.name == map['weightGoal'],
          orElse: () => WeightGoal.maintain,
        ),
      );
}
