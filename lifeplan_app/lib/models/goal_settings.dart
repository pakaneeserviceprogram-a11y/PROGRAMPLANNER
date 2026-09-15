/// User-editable numeric goals used to compute progress across screens
/// (DATA_MODEL.md — SavingGoal, SalesGoal, ExerciseWeeklyGoal, NutritionGoal).
/// Stored as a single document; missing fields fall back to the defaults below.
class GoalSettings {
  static const defaultSavingTarget = 50000.0;
  static const defaultSalesTarget = 250000.0;
  static const defaultExerciseWeeklyTarget = 5;

  // ค่าเริ่มต้นโภชนาการต่อวัน — อ้างอิงคนทำงานทั่วไป ปรับเองได้ในหน้าตั้งค่าเป้าหมาย
  static const defaultCalorieTarget = 2000;
  static const defaultProteinTarget = 60.0; // กรัม
  static const defaultCarbTarget = 250.0; // กรัม (แป้ง/คาร์โบไฮเดรต)
  static const defaultFatTarget = 65.0; // กรัม
  static const defaultSugarLimit = 25.0; // กรัม — เพดานตามคำแนะนำ WHO
  static const defaultWaterTargetMl = 2000; // มล. (8 แก้ว)

  final double savingTarget;
  final double salesTarget;
  final int exerciseWeeklyTarget;
  final int calorieTarget;
  final double proteinTarget;
  final double carbTarget;
  final double fatTarget;
  final double sugarLimit;
  final int waterTargetMl;

  const GoalSettings({
    this.savingTarget = defaultSavingTarget,
    this.salesTarget = defaultSalesTarget,
    this.exerciseWeeklyTarget = defaultExerciseWeeklyTarget,
    this.calorieTarget = defaultCalorieTarget,
    this.proteinTarget = defaultProteinTarget,
    this.carbTarget = defaultCarbTarget,
    this.fatTarget = defaultFatTarget,
    this.sugarLimit = defaultSugarLimit,
    this.waterTargetMl = defaultWaterTargetMl,
  });

  GoalSettings copyWith({
    double? savingTarget,
    double? salesTarget,
    int? exerciseWeeklyTarget,
    int? calorieTarget,
    double? proteinTarget,
    double? carbTarget,
    double? fatTarget,
    double? sugarLimit,
    int? waterTargetMl,
  }) =>
      GoalSettings(
        savingTarget: savingTarget ?? this.savingTarget,
        salesTarget: salesTarget ?? this.salesTarget,
        exerciseWeeklyTarget: exerciseWeeklyTarget ?? this.exerciseWeeklyTarget,
        calorieTarget: calorieTarget ?? this.calorieTarget,
        proteinTarget: proteinTarget ?? this.proteinTarget,
        carbTarget: carbTarget ?? this.carbTarget,
        fatTarget: fatTarget ?? this.fatTarget,
        sugarLimit: sugarLimit ?? this.sugarLimit,
        waterTargetMl: waterTargetMl ?? this.waterTargetMl,
      );

  Map<String, dynamic> toMap() => {
        'savingTarget': savingTarget,
        'salesTarget': salesTarget,
        'exerciseWeeklyTarget': exerciseWeeklyTarget,
        'calorieTarget': calorieTarget,
        'proteinTarget': proteinTarget,
        'carbTarget': carbTarget,
        'fatTarget': fatTarget,
        'sugarLimit': sugarLimit,
        'waterTargetMl': waterTargetMl,
      };

  factory GoalSettings.fromMap(Map<String, dynamic> map) => GoalSettings(
        savingTarget: (map['savingTarget'] as num?)?.toDouble() ?? defaultSavingTarget,
        salesTarget: (map['salesTarget'] as num?)?.toDouble() ?? defaultSalesTarget,
        exerciseWeeklyTarget: (map['exerciseWeeklyTarget'] as num?)?.toInt() ?? defaultExerciseWeeklyTarget,
        calorieTarget: (map['calorieTarget'] as num?)?.toInt() ?? defaultCalorieTarget,
        proteinTarget: (map['proteinTarget'] as num?)?.toDouble() ?? defaultProteinTarget,
        carbTarget: (map['carbTarget'] as num?)?.toDouble() ?? defaultCarbTarget,
        fatTarget: (map['fatTarget'] as num?)?.toDouble() ?? defaultFatTarget,
        sugarLimit: (map['sugarLimit'] as num?)?.toDouble() ?? defaultSugarLimit,
        waterTargetMl: (map['waterTargetMl'] as num?)?.toInt() ?? defaultWaterTargetMl,
      );
}
