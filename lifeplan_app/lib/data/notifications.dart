import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/schedule_event.dart';
import 'repositories/app_settings_repository.dart';
import 'repositories/schedule_repository.dart';

/// แจ้งเตือนกิจกรรมในตารางเวลา — ตั้งเป็นการเตือนรายสัปดาห์ซ้ำทุกสัปดาห์
/// ให้ตรงกับตารางที่เป็นแบบ "ประจำสัปดาห์" (ดู ScheduleEvent.weekday)
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channel = AndroidNotificationChannel(
    'schedule_reminders',
    'เตือนกิจกรรมในตารางเวลา',
    description: 'แจ้งเตือนก่อนถึงเวลากิจกรรมที่บันทึกไว้ในตารางเวลา',
    importance: Importance.high,
  );

  /// เรียกครั้งเดียวตอนแอปเริ่ม ก่อนใช้งานฟังก์ชันอื่น
  static Future<void> init() async {
    if (_ready) return;

    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (e) {
      // อ่านโซนเวลาไม่ได้ (บางเครื่อง/บาง test) — ถอยไปใช้เวลาไทยซึ่งเป็นผู้ใช้หลัก
      debugPrint('อ่านโซนเวลาของเครื่องไม่ได้ ใช้ Asia/Bangkok แทน: $e');
      tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notification')),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    _ready = true;
  }

  /// ขอสิทธิ์แจ้งเตือน (Android 13+) — คืน true เมื่อผู้ใช้อนุญาต
  static Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // แพลตฟอร์มที่ไม่ต้องขอสิทธิ์
    // ตั้งเตือนแบบ inexact (คลาดได้ไม่กี่นาที) จึงไม่ต้องขอสิทธิ์ SCHEDULE_EXACT_ALARM
    // ซึ่งจะเด้งผู้ใช้ออกไปหน้าตั้งค่าของระบบโดยไม่จำเป็น
    return await android.requestNotificationsPermission() ?? false;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'schedule_reminders',
      'เตือนกิจกรรมในตารางเวลา',
      channelDescription: 'แจ้งเตือนก่อนถึงเวลากิจกรรมที่บันทึกไว้ในตารางเวลา',
      importance: Importance.high,
      priority: Priority.high,
      // ไอคอนแถบสถานะต้องเป็นภาพขาวล้วนโปร่งใส ไม่ใช่ไอคอนแอปสี (Android จะตัดเป็นเงา)
      icon: 'ic_notification',
      color: Color(0xFF5B57E8),
    ),
  );

  /// ล้างการเตือนเดิมทั้งหมดแล้วตั้งใหม่จากตารางเวลาปัจจุบัน
  ///
  /// เรียกทุกครั้งที่ตารางหรือการตั้งค่าเปลี่ยน — ถูกกว่าการไล่แก้ทีละรายการ
  /// และไม่มีทางหลงเหลือการเตือนของกิจกรรมที่ลบไปแล้ว
  static Future<int> syncScheduleReminders() async {
    await init();
    await _plugin.cancelAll();

    final settings = AppSettingsRepository().get();
    if (!settings.scheduleRemindersEnabled) return 0;

    final events = ScheduleRepository().getAll();
    var scheduled = 0;
    for (var i = 0; i < events.length; i++) {
      final when = _nextOccurrence(events[i], settings.remindMinutesBefore);
      if (when == null) continue;

      await _plugin.zonedSchedule(
        id: i,
        scheduledDate: when,
        title: events[i].title,
        body: _bodyFor(events[i], settings.remindMinutesBefore),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // ซ้ำทุกสัปดาห์ในวัน+เวลาเดียวกัน
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      scheduled++;
    }
    return scheduled;
  }

  static String _bodyFor(ScheduleEvent event, int minutesBefore) {
    final head = minutesBefore == 0 ? 'ถึงเวลา ${event.time}' : 'อีก $minutesBefore นาที (${event.time})';
    return event.subtitle == null ? head : '$head • ${event.subtitle}';
  }

  /// เวลาที่จะเตือนครั้งถัดไปของกิจกรรมนี้ (ในอนาคตเสมอ)
  @visibleForTesting
  static tz.TZDateTime? nextOccurrenceOf(ScheduleEvent event, int minutesBefore, {tz.TZDateTime? now}) =>
      _nextOccurrence(event, minutesBefore, now: now);

  static tz.TZDateTime? _nextOccurrence(ScheduleEvent event, int minutesBefore, {tz.TZDateTime? now}) {
    final parts = event.time.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    final current = now ?? tz.TZDateTime.now(tz.local);

    // หาเวลา "เริ่มกิจกรรม" ครั้งถัดไปก่อน แล้วค่อยลบเวลาเตือนล่วงหน้าทีหลัง
    // (ลบก่อนจะเพี้ยนเมื่อการเตือนข้ามเที่ยงคืนไปอยู่คนละวันกับตัวกิจกรรม)
    var start = tz.TZDateTime(tz.local, current.year, current.month, current.day, hour, minute);
    start = start.add(Duration(days: (event.weekday - start.weekday + 7) % 7));

    var remindAt = start.subtract(Duration(minutes: minutesBefore));
    if (!remindAt.isAfter(current)) remindAt = remindAt.add(const Duration(days: 7));
    return remindAt;
  }

  /// แจ้งเตือนทดสอบทันที เพื่อให้ผู้ใช้เห็นว่าสิทธิ์ผ่านแล้วจริง
  static Future<void> showTestNotification() async {
    await init();
    await _plugin.show(
      id: 9999,
      title: 'LifePlan พร้อมเตือนคุณแล้ว',
      body: 'ถ้าเห็นข้อความนี้ แปลว่าการแจ้งเตือนทำงานปกติ',
      notificationDetails: _details,
    );
  }

  /// จำนวนการเตือนที่ตั้งค้างไว้ในระบบตอนนี้
  static Future<int> pendingCount() async {
    await init();
    return (await _plugin.pendingNotificationRequests()).length;
  }
}
