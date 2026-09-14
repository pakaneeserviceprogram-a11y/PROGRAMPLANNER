import '../models/life_category.dart';

class ScheduleEvent {
  final String id;
  final String time; // "HH:mm", zero-padded so string-sort == time-sort
  final String title;
  final String? subtitle;
  final LifeCategory category;

  const ScheduleEvent({
    required this.id,
    required this.time,
    required this.title,
    this.subtitle,
    required this.category,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'time': time,
        'title': title,
        'subtitle': subtitle,
        'category': category.name,
      };

  factory ScheduleEvent.fromMap(Map<String, dynamic> map) => ScheduleEvent(
        id: map['id'] as String,
        time: map['time'] as String,
        title: map['title'] as String,
        subtitle: map['subtitle'] as String?,
        category: LifeCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => LifeCategory.work),
      );
}
