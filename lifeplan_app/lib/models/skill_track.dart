class SkillTrack {
  final String id;
  final String name;
  final String subtitle;
  final int progressPercent;
  final bool isPrimary;

  const SkillTrack({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.progressPercent,
    this.isPrimary = false,
  });

  SkillTrack copyWith({int? progressPercent}) => SkillTrack(
        id: id,
        name: name,
        subtitle: subtitle,
        progressPercent: progressPercent ?? this.progressPercent,
        isPrimary: isPrimary,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'progressPercent': progressPercent,
        'isPrimary': isPrimary,
      };

  factory SkillTrack.fromMap(Map<String, dynamic> map) => SkillTrack(
        id: map['id'] as String,
        name: map['name'] as String,
        subtitle: map['subtitle'] as String,
        progressPercent: (map['progressPercent'] as num).toInt(),
        isPrimary: map['isPrimary'] as bool? ?? false,
      );
}
