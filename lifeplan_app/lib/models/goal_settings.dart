/// User-editable numeric goals used to compute progress across screens
/// (DATA_MODEL.md — SavingGoal, SalesGoal, ExerciseWeeklyGoal). Stored as a
/// single document; missing fields fall back to the defaults below.
class GoalSettings {
  static const defaultSavingTarget = 50000.0;
  static const defaultSalesTarget = 250000.0;
  static const defaultExerciseWeeklyTarget = 5;

  final double savingTarget;
  final double salesTarget;
  final int exerciseWeeklyTarget;

  const GoalSettings({
    this.savingTarget = defaultSavingTarget,
    this.salesTarget = defaultSalesTarget,
    this.exerciseWeeklyTarget = defaultExerciseWeeklyTarget,
  });

  GoalSettings copyWith({double? savingTarget, double? salesTarget, int? exerciseWeeklyTarget}) => GoalSettings(
        savingTarget: savingTarget ?? this.savingTarget,
        salesTarget: salesTarget ?? this.salesTarget,
        exerciseWeeklyTarget: exerciseWeeklyTarget ?? this.exerciseWeeklyTarget,
      );

  Map<String, dynamic> toMap() => {
        'savingTarget': savingTarget,
        'salesTarget': salesTarget,
        'exerciseWeeklyTarget': exerciseWeeklyTarget,
      };

  factory GoalSettings.fromMap(Map<String, dynamic> map) => GoalSettings(
        savingTarget: (map['savingTarget'] as num?)?.toDouble() ?? defaultSavingTarget,
        salesTarget: (map['salesTarget'] as num?)?.toDouble() ?? defaultSalesTarget,
        exerciseWeeklyTarget: (map['exerciseWeeklyTarget'] as num?)?.toInt() ?? defaultExerciseWeeklyTarget,
      );
}
