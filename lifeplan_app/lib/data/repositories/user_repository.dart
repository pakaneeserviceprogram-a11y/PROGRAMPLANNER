import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/user_profile.dart';
import '../hive_boxes.dart';

/// The signed-in user is a single document stored under the fixed key
/// 'current' — LifePlan is single-account on-device for now.
class UserRepository {
  static const _key = 'current';
  Box<Map> get _box => Hive.box<Map>(HiveBoxes.userProfile);

  UserProfile? getCurrent() {
    final map = _box.get(_key);
    if (map == null) return null;
    return UserProfile.fromMap(Map<String, dynamic>.from(map));
  }

  Future<void> save(UserProfile user) => _box.put(_key, user.toMap());

  Future<void> signOut() => _box.delete(_key);

  ValueListenable<Box<Map>> listenable() => _box.listenable();
}
