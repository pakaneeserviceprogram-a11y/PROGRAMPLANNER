import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings.dart';
import 'backup.dart';

/// เตือนให้สำรองข้อมูล — ข้อมูลทั้งหมดอยู่ในเครื่องอย่างเดียว มือถือหาย/ถอนแอป = หายหมด
///
/// เป็นฟังก์ชันล้วนทั้งหมด (คำนวณจาก `AppSettings` + เวลาปัจจุบัน) จึงเทสต์ได้ตรง ๆ
class BackupReminder {
  BackupReminder._();

  /// เวลาที่เตือนในแต่ละวัน (สองทุ่ม — ช่วงที่คนว่างพอจะกดสำรองจริง)
  static const reminderHour = 20;

  /// มีข้อมูลที่เสียหายแล้วน่าเสียดายหรือยัง — ผู้ใช้ใหม่ที่ยังไม่มีอะไรไม่ต้องโดนเตือน
  ///
  /// ข้าม box ที่ยังไม่ถูกเปิด แทนที่จะโยน error — หน้าหลักเรียกทุกครั้งที่ rebuild
  /// จึงต้องไม่พังเพราะ box ใด box หนึ่งยังไม่ได้เปิด
  static bool hasDataWorthBackingUp() => BackupService.recordBoxNames
      .any((name) => Hive.isBoxOpen(name) && Hive.box<Map>(name).isNotEmpty);

  /// สำรองครั้งล่าสุดผ่านมากี่วัน — ยังไม่เคยสำรองเลย = null
  static int? daysSinceBackup(AppSettings settings, {DateTime? now}) {
    final last = settings.lastBackupAt;
    if (last == null) return null;
    final today = now ?? DateTime.now();
    return DateTime(today.year, today.month, today.day)
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
  }

  /// ถึงเวลาเตือนหรือยัง (ปิดการเตือนไว้ = ไม่เตือน, ยังไม่มีข้อมูล = ไม่เตือน)
  static bool isOverdue(AppSettings settings, {required bool hasData, DateTime? now}) {
    if (!settings.backupReminderEnabled || !hasData) return false;
    final days = daysSinceBackup(settings, now: now);
    return days == null || days >= settings.backupReminderDays;
  }

  /// ข้อความบนแบนเนอร์หน้าหลัก
  static String bannerMessage(AppSettings settings, {DateTime? now}) {
    final days = daysSinceBackup(settings, now: now);
    if (days == null) return 'ยังไม่เคยสำรองข้อมูลเลย — ถ้ามือถือหายหรือถอนแอป ข้อมูลจะหายทั้งหมด';
    return 'สำรองข้อมูลล่าสุดเมื่อ $days วันก่อน — กดเพื่อสำรองเก็บไว้';
  }

  /// เวลาแจ้งเตือนครั้งถัดไป (null = ปิดอยู่)
  ///
  /// ครบกำหนดเมื่อ: สำรองล่าสุด + จำนวนวันที่ตั้งไว้ แล้วเตือนตอน [reminderHour]
  /// ของวันนั้น — ถ้าเวลานั้นผ่านไปแล้ว (หรือยังไม่เคยสำรอง) เตือนรอบถัดไปที่จะถึง
  static DateTime? nextReminderAt(AppSettings settings, {DateTime? now}) {
    if (!settings.backupReminderEnabled) return null;

    final current = now ?? DateTime.now();
    final last = settings.lastBackupAt;
    final dueDay = last == null
        ? DateTime(current.year, current.month, current.day)
        : DateTime(last.year, last.month, last.day + settings.backupReminderDays);

    var at = DateTime(dueDay.year, dueDay.month, dueDay.day, reminderHour);
    // เลยเวลาไปแล้วก็ขยับไปวันถัดไป จนกว่าจะเป็นเวลาในอนาคต (กันตั้งเตือนย้อนหลัง)
    while (!at.isAfter(current)) {
      at = DateTime(at.year, at.month, at.day + 1, reminderHour);
    }
    return at;
  }
}
