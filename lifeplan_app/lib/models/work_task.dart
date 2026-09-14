enum TaskStatus { todo, inProgress, done }

enum TaskPriority { urgent, normal, low }

class WorkTask {
  final String id;
  final String title;
  final TaskStatus status;
  final TaskPriority priority;
  final String? dueLabel;
  final int? progressPercent;

  const WorkTask({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.dueLabel,
    this.progressPercent,
  });

  WorkTask copyWith({TaskStatus? status, int? progressPercent}) => WorkTask(
        id: id,
        title: title,
        status: status ?? this.status,
        priority: priority,
        dueLabel: dueLabel,
        progressPercent: progressPercent ?? this.progressPercent,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'status': status.name,
        'priority': priority.name,
        'dueLabel': dueLabel,
        'progressPercent': progressPercent,
      };

  factory WorkTask.fromMap(Map<String, dynamic> map) => WorkTask(
        id: map['id'] as String,
        title: map['title'] as String,
        status: TaskStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => TaskStatus.todo),
        priority: TaskPriority.values.firstWhere((e) => e.name == map['priority'], orElse: () => TaskPriority.normal),
        dueLabel: map['dueLabel'] as String?,
        progressPercent: (map['progressPercent'] as num?)?.toInt(),
      );
}
