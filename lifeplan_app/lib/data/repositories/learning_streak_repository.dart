import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../hive_boxes.dart';

class LearningStreak {
  final int currentStreakDays;
  final DateTime? lastLoggedDate;
  final int lessonsLoggedToday;

  const LearningStreak({
    this.currentStreakDays = 0,
    this.lastLoggedDate,
    this.lessonsLoggedToday = 0,
  });

  bool get loggedToday {
    if (lastLoggedDate == null) return false;
    final now = DateTime.now();
    return lastLoggedDate!.year == now.year && lastLoggedDate!.month == now.month && lastLoggedDate!.day == now.day;
  }
}

/// Single-document box tracking the learner's daily streak.
class LearningStreakRepository {
  static const _key = 'current';
  Box<Map> get _box => Hive.box<Map>(HiveBoxes.learningStreak);

  LearningStreak get() {
    final map = _box.get(_key);
    if (map == null) return const LearningStreak();
    return LearningStreak(
      currentStreakDays: (map['currentStreakDays'] as num?)?.toInt() ?? 0,
      lastLoggedDate: map['lastLoggedDate'] != null ? DateTime.parse(map['lastLoggedDate'] as String) : null,
      lessonsLoggedToday: (map['lessonsLoggedToday'] as num?)?.toInt() ?? 0,
    );
  }

  /// Call when the user logs a learning session today. Increments the streak
  /// once per calendar day (resets to 1 if more than a day was skipped).
  Future<LearningStreak> logSessionToday() async {
    final current = get();
    final now = DateTime.now();
    if (current.loggedToday) {
      final updated = LearningStreak(
        currentStreakDays: current.currentStreakDays,
        lastLoggedDate: now,
        lessonsLoggedToday: current.lessonsLoggedToday + 1,
      );
      await _put(updated);
      return updated;
    }

    final isConsecutiveDay = current.lastLoggedDate != null &&
        now.difference(DateTime(current.lastLoggedDate!.year, current.lastLoggedDate!.month, current.lastLoggedDate!.day)).inDays == 1;

    final updated = LearningStreak(
      currentStreakDays: isConsecutiveDay ? current.currentStreakDays + 1 : 1,
      lastLoggedDate: now,
      lessonsLoggedToday: 1,
    );
    await _put(updated);
    return updated;
  }

  Future<void> _put(LearningStreak s) => _box.put(_key, {
        'currentStreakDays': s.currentStreakDays,
        'lastLoggedDate': s.lastLoggedDate?.toIso8601String(),
        'lessonsLoggedToday': s.lessonsLoggedToday,
      });

  ValueListenable<Box<Map>> listenable() => _box.listenable();
}
