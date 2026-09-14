enum ExerciseType { run, strength, swim, cycle, hike, stretch, other }

class ExercisePlanItem {
  final String id;
  final String title;
  final ExerciseType type;
  final String dayLabel;
  final int durationMinutes;
  final bool isDone;
  final bool isToday;

  const ExercisePlanItem({
    required this.id,
    required this.title,
    required this.type,
    required this.dayLabel,
    required this.durationMinutes,
    this.isDone = false,
    this.isToday = false,
  });

  ExercisePlanItem copyWith({bool? isDone}) => ExercisePlanItem(
        id: id,
        title: title,
        type: type,
        dayLabel: dayLabel,
        durationMinutes: durationMinutes,
        isDone: isDone ?? this.isDone,
        isToday: isToday,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type.name,
        'dayLabel': dayLabel,
        'durationMinutes': durationMinutes,
        'isDone': isDone,
        'isToday': isToday,
      };

  factory ExercisePlanItem.fromMap(Map<String, dynamic> map) => ExercisePlanItem(
        id: map['id'] as String,
        title: map['title'] as String,
        type: ExerciseType.values.firstWhere((e) => e.name == map['type'], orElse: () => ExerciseType.other),
        dayLabel: map['dayLabel'] as String,
        durationMinutes: (map['durationMinutes'] as num).toInt(),
        isDone: map['isDone'] as bool? ?? false,
        isToday: map['isToday'] as bool? ?? false,
      );
}
