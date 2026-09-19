import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/body_profile.dart';
import '../hive_boxes.dart';

/// Single-document box เก็บข้อมูลร่างกายของผู้ใช้ (ยังไม่กรอก = ค่าเริ่มต้นที่ยังไม่ครบ)
class BodyProfileRepository {
  static const _key = 'current';
  Box<Map> get _box => Hive.box<Map>(HiveBoxes.bodyProfile);

  BodyProfile get() {
    final map = _box.get(_key);
    if (map == null) return const BodyProfile();
    return BodyProfile.fromMap(Map<String, dynamic>.from(map));
  }

  Future<void> save(BodyProfile profile) => _box.put(_key, profile.toMap());

  ValueListenable<Box<Map>> listenable() => _box.listenable();
}
