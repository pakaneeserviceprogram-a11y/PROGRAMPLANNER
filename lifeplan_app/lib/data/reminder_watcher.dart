import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/schedule_event.dart';
import 'repositories/app_settings_repository.dart';
import 'repositories/schedule_repository.dart';

/// กิจกรรมหนึ่งรายการที่ "ถึงเวลาเตือน" แล้ว พร้อมเวลาที่ควรเตือน
class DueReminder {
  final ScheduleEvent event;

  /// เวลาที่ควรเด้งเตือน (= เวลากิจกรรม ลบด้วยจำนวนนาทีเตือนล่วงหน้า)
  final DateTime remindAt;

  /// เตือนล่วงหน้ากี่นาที ณ ตอนที่คำนวณ (0 = ตรงเวลากิจกรรม)
  final int minutesBefore;

  const DueReminder({required this.event, required this.remindAt, required this.minutesBefore});

  /// คีย์ประจำ "ครั้ง" ของการเตือน — ใช้กันไม่ให้เด้งซ้ำรอบเดิม
  /// (กิจกรรมเดิมของสัปดาห์หน้าได้คีย์ใหม่ จึงยังเด้งได้ตามปกติ)
  String get occurrenceKey => '${event.id}@${remindAt.toIso8601String()}';

  @override
  String toString() => 'DueReminder($occurrenceKey)';
}

/// คอยดูว่าถึงเวลากิจกรรมในตารางหรือยัง แล้วเรียก [onDue] เพื่อให้ UI เด้งป๊อปอัป
///
/// การแจ้งเตือนของระบบ (ดู `NotificationService`) ตั้งแบบ inexact และเป็นคนละกลไกกัน
/// ตัวนี้ทำงานเฉพาะตอนแอปเปิดอยู่ เพื่อให้ป๊อปอัปเด้ง "ตรงเวลา" ไม่ต้องรอ Android ปลุก
class ReminderWatcher {
  /// จังหวะตรวจ — ถี่พอให้ป๊อปอัปคลาดจากเวลาจริงไม่เกินครึ่งนาที
  static const checkInterval = Duration(seconds: 20);

  /// เปิดแอปมาแล้วเจอว่าเพิ่งเลยเวลาเตือนไปไม่เกินเท่านี้ ให้เด้งย้อนหลังให้ด้วย
  /// (เผื่อผู้ใช้เพิ่งกดเปิดแอปจากการแจ้งเตือนที่เพิ่งดัง)
  static const catchUpWindow = Duration(minutes: 3);

  final void Function(DueReminder) onDue;
  final ScheduleRepository _schedule;
  final AppSettingsRepository _settings;

  Timer? _timer;
  DateTime? _checkedUpTo;
  final _shown = <String>{};

  ReminderWatcher({
    required this.onDue,
    ScheduleRepository? schedule,
    AppSettingsRepository? settings,
  })  : _schedule = schedule ?? ScheduleRepository(),
        _settings = settings ?? AppSettingsRepository();

  /// เริ่มตรวจ (เรียกซ้ำได้ — จะรีสตาร์ตตัวจับเวลาให้)
  void start() {
    _timer?.cancel();
    // เริ่มนับจาก "เมื่อครู่นี้" เพื่อให้จับการเตือนที่เพิ่งเลยไปตอนแอปยังไม่เปิดได้
    _checkedUpTo = DateTime.now().subtract(catchUpWindow);
    check();
    _timer = Timer.periodic(checkInterval, (_) => check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  /// ตรวจช่วงเวลาตั้งแต่ครั้งก่อนจนถึงตอนนี้ แล้วยิง [onDue] ทีละรายการ
  @visibleForTesting
  void check({DateTime? now}) {
    final to = now ?? DateTime.now();
    final from = _checkedUpTo ?? to.subtract(catchUpWindow);
    _checkedUpTo = to;

    final settings = _settings.get();
    if (!settings.scheduleRemindersEnabled || !settings.popupEnabled) return;

    for (final due in dueBetween(_schedule.getAll(), settings, from: from, to: to)) {
      if (!_shown.add(due.occurrenceKey)) continue;
      onDue(due);
    }
  }

  /// กิจกรรมที่ถึงเวลาเตือนในช่วง (from, to] เรียงตามเวลาเตือน
  @visibleForTesting
  static List<DueReminder> dueBetween(
    List<ScheduleEvent> events,
    AppSettings settings, {
    required DateTime from,
    required DateTime to,
  }) {
    final minutesBefore = settings.remindMinutesBefore;
    final due = <DueReminder>[];
    for (final event in events) {
      final remindAt = lastRemindAtOrBefore(event, minutesBefore, to);
      if (remindAt == null) continue;
      if (remindAt.isAfter(from) && !remindAt.isAfter(to)) {
        due.add(DueReminder(event: event, remindAt: remindAt, minutesBefore: minutesBefore));
      }
    }
    due.sort((a, b) => a.remindAt.compareTo(b.remindAt));
    return due;
  }

  /// เวลาเตือนครั้งล่าสุดของกิจกรรมนี้ที่ไม่เลย [at] (คู่ตรงข้ามของ
  /// `NotificationService.nextOccurrenceOf` ซึ่งมองไปข้างหน้า)
  @visibleForTesting
  static DateTime? lastRemindAtOrBefore(ScheduleEvent event, int minutesBefore, DateTime at) {
    final parts = event.time.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    // หาเวลา "เริ่มกิจกรรม" ของรอบล่าสุดก่อน แล้วค่อยลบเวลาเตือนล่วงหน้าทีหลัง
    // (ลบก่อนจะเพี้ยนเมื่อการเตือนข้ามเที่ยงคืนไปอยู่คนละวันกับตัวกิจกรรม)
    var start = DateTime(at.year, at.month, at.day, hour, minute);
    start = start.subtract(Duration(days: (start.weekday - event.weekday + 7) % 7));

    var remindAt = start.subtract(Duration(minutes: minutesBefore));
    if (remindAt.isAfter(at)) remindAt = remindAt.subtract(const Duration(days: 7));
    return remindAt;
  }
}
