import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/goal_settings.dart';
import '../hive_boxes.dart';

/// Single-document box holding the user's goals. Returns defaults until the
/// user saves their own values from GoalSettingsScreen.
class GoalSettingsRepository {
  static const _key = 'current';
  Box<Map> get _box => Hive.box<Map>(HiveBoxes.goalSettings);

  GoalSettings get() {
    final map = _box.get(_key);
    if (map == null) return const GoalSettings();
    return GoalSettings.fromMap(Map<String, dynamic>.from(map));
  }

  Future<void> save(GoalSettings goals) => _box.put(_key, goals.toMap());

  ValueListenable<Box<Map>> listenable() => _box.listenable();
}
