import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/app_settings.dart';
import '../hive_boxes.dart';

/// Single-document box holding app-wide preferences (notifications, ...).
class AppSettingsRepository {
  static const _key = 'current';
  Box<Map> get _box => Hive.box<Map>(HiveBoxes.appSettings);

  AppSettings get() {
    final map = _box.get(_key);
    if (map == null) return const AppSettings();
    return AppSettings.fromMap(Map<String, dynamic>.from(map));
  }

  Future<void> save(AppSettings settings) => _box.put(_key, settings.toMap());

  ValueListenable<Box<Map>> listenable() => _box.listenable();
}
