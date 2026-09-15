import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'hive_boxes.dart';

/// รูปแบบไฟล์สำรองข้อมูล — ขึ้นเลขเวอร์ชันเมื่อโครงสร้างเปลี่ยนจนอ่านของเก่าไม่ได้
const int backupFormatVersion = 1;

/// ข้อผิดพลาดที่อธิบายเป็นภาษาไทยได้เลย เพื่อเอาไปโชว์ใน SnackBar ตรง ๆ
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// สำรอง/กู้คืนข้อมูลทั้งหมดเป็น JSON ก้อนเดียว
///
/// อ่าน-เขียน Hive box ตรง ๆ ทีละ box (ไม่ผ่าน model) เพื่อให้ข้อมูลที่เขียนไว้
/// ก่อนหน้าไม่หายแม้ model จะเพิ่มฟิลด์ใหม่ภายหลัง — ฝั่งอ่านของแต่ละ model
/// มี default ให้ฟิลด์ที่ขาดอยู่แล้ว
class BackupService {
  BackupService._();

  static const List<String> _boxNames = [
    HiveBoxes.userProfile,
    HiveBoxes.workTasks,
    HiveBoxes.exerciseItems,
    HiveBoxes.clients,
    HiveBoxes.financeTransactions,
    HiveBoxes.skillTracks,
    HiveBoxes.scheduleEvents,
    HiveBoxes.learningStreak,
    HiveBoxes.goalSettings,
  ];

  /// ชื่อไฟล์ที่แนะนำ เช่น `lifeplan-backup-2026-09-15-1433.json`
  static String suggestedFileName([DateTime? at]) {
    final t = at ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'lifeplan-backup-${t.year}-${two(t.month)}-${two(t.day)}-${two(t.hour)}${two(t.minute)}.json';
  }

  /// รวมทุก box เป็น JSON string (จัดย่อหน้าให้อ่านด้วยตาได้)
  static String exportToJson() {
    final boxes = <String, dynamic>{};
    for (final name in _boxNames) {
      final box = Hive.box<Map>(name);
      boxes[name] = {
        for (final key in box.keys) key.toString(): Map<String, dynamic>.from(box.get(key)!),
      };
    }

    return const JsonEncoder.withIndent('  ').convert({
      'app': 'lifeplan',
      'formatVersion': backupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'boxes': boxes,
    });
  }

  /// จำนวนรายการต่อ box ในไฟล์สำรอง — ใช้โชว์ให้ผู้ใช้ยืนยันก่อนกู้คืนจริง
  static Map<String, int> summarize(String jsonText) {
    final boxes = _parseAndValidate(jsonText);
    return {
      for (final entry in boxes.entries) entry.key: (entry.value as Map).length,
    };
  }

  /// เขียนทับข้อมูลทั้งหมดด้วยไฟล์สำรอง — ของเดิมในเครื่องจะถูกล้างก่อน
  ///
  /// ตรวจไฟล์ให้ครบก่อนแตะข้อมูลจริงแม้แต่ box เดียว ไฟล์เสียจะไม่ทำให้
  /// ข้อมูลเดิมหายไปครึ่ง ๆ กลาง ๆ
  static Future<void> importFromJson(String jsonText) async {
    final boxes = _parseAndValidate(jsonText);

    // แปลงให้ครบทุก box ก่อน แล้วค่อยเขียน
    final staged = <String, Map<String, Map<String, dynamic>>>{};
    for (final name in _boxNames) {
      final raw = boxes[name];
      if (raw == null) continue; // ไฟล์จากเวอร์ชันก่อนที่ยังไม่มี box นี้
      if (raw is! Map) throw BackupException('ไฟล์สำรองเสียหาย: ข้อมูลส่วน "$name" ไม่ถูกต้อง');
      staged[name] = {
        for (final entry in raw.entries)
          entry.key.toString(): entry.value is Map
              ? Map<String, dynamic>.from(entry.value as Map)
              : throw BackupException('ไฟล์สำรองเสียหาย: รายการใน "$name" ไม่ถูกต้อง'),
      };
    }

    for (final entry in staged.entries) {
      final box = Hive.box<Map>(entry.key);
      await box.clear();
      await box.putAll(entry.value);
    }
  }

  static Map<String, dynamic> _parseAndValidate(String jsonText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      throw const BackupException('ไฟล์นี้ไม่ใช่ JSON ที่อ่านได้');
    }

    if (decoded is! Map || decoded['app'] != 'lifeplan') {
      throw const BackupException('ไฟล์นี้ไม่ใช่ไฟล์สำรองของ LifePlan');
    }

    final version = decoded['formatVersion'];
    if (version is! int) {
      throw const BackupException('ไฟล์สำรองไม่มีเลขเวอร์ชัน');
    }
    if (version > backupFormatVersion) {
      throw BackupException('ไฟล์สำรองมาจากแอปเวอร์ชันใหม่กว่า (รูปแบบ v$version) — กรุณาอัปเดตแอปก่อน');
    }

    final boxes = decoded['boxes'];
    if (boxes is! Map) {
      throw const BackupException('ไฟล์สำรองเสียหาย: ไม่พบข้อมูล');
    }
    return Map<String, dynamic>.from(boxes);
  }
}
