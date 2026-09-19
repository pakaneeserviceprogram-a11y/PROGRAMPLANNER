import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_settings.dart';
import '../models/schedule_event.dart';
import 'backup_reminder.dart';
import 'repositories/app_settings_repository.dart';
import 'repositories/schedule_repository.dart';

/// แจ้งเตือนกิจกรรมในตารางเวลา — กิจกรรมประจำสัปดาห์ตั้งเป็นการเตือนซ้ำทุกสัปดาห์
/// (ดู ScheduleEvent.weekday) ส่วนนัดหมายเฉพาะวันที่ (ScheduleEvent.date) เตือนครั้งเดียว
///
/// เสียงและการสั่นบน Android ผูกกับ "ช่อง" (channel) และแก้ไม่ได้หลังสร้างช่องแล้ว
/// จึงใช้หนึ่งช่องต่อหนึ่งรูปแบบ (เสียง/สั่น เปิด-ปิด) แล้วลบช่องที่ไม่ได้ใช้ทิ้ง
/// เวลาผู้ใช้สลับสวิตช์ — ไม่งั้นการปิดเสียงจะไม่มีผลจนกว่าจะถอนแอปติดตั้งใหม่
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// ไฟล์เสียงใน android/app/src/main/res/raw/alarm_chime.wav
  static const _soundResource = RawResourceAndroidNotificationSound('alarm_chime');
  static final _vibrationPattern = Int64List.fromList([0, 400, 200, 400, 200, 600]);

  /// ช่องรุ่นแรกที่ยังไม่รองรับเสียง/สั่นแยกกัน — ลบทิ้งตอน sync
  static const _legacyChannelId = 'schedule_reminders';

  /// id ของกิจกรรมที่ผู้ใช้กดจากแถบแจ้งเตือน — หน้าจอหลักคอยฟังเพื่อเปิดป๊อปอัปให้
  static final _tapped = StreamController<String>.broadcast();
  static Stream<String> get tappedEventIds => _tapped.stream;

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
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _tapped.add(payload);
      },
    );

    _ready = true;
  }

  /// ถ้าแอปถูกเปิดขึ้นมาด้วยการกดแจ้งเตือน จะคืน id ของกิจกรรมนั้น (ไม่งั้นคืน null)
  ///
  /// ต่างจาก [tappedEventIds] ตรงที่กรณีนี้แอปยังไม่ทันรันตอนผู้ใช้กด จึงยังไม่มีใครฟัง stream
  static Future<String?> launchEventId() async {
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final payload = details?.notificationResponse?.payload;
    return (payload == null || payload.isEmpty) ? null : payload;
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

  /// ชื่อช่องแจ้งเตือนของรูปแบบเสียง/สั่นหนึ่ง ๆ — ต้องไม่ซ้ำกันข้ามรูปแบบ
  @visibleForTesting
  static String channelIdFor(AppSettings settings) =>
      'schedule_reminders_s${settings.soundEnabled ? 1 : 0}_v${settings.vibrationEnabled ? 1 : 0}';

  /// ทุกช่องที่แอปนี้เคยสร้างได้ (ใช้ไล่ลบช่องที่ไม่ได้ใช้แล้ว)
  static Iterable<String> get _allChannelIds sync* {
    yield _legacyChannelId;
    for (final sound in [true, false]) {
      for (final vibration in [true, false]) {
        yield channelIdFor(AppSettings(soundEnabled: sound, vibrationEnabled: vibration));
      }
    }
  }

  static String _channelName(AppSettings settings) {
    final sound = settings.soundEnabled ? 'มีเสียง' : 'ไม่มีเสียง';
    final vibration = settings.vibrationEnabled ? 'สั่น' : 'ไม่สั่น';
    return 'เตือนกิจกรรมในตารางเวลา ($sound/$vibration)';
  }

  static const _channelDescription = 'แจ้งเตือนก่อนถึงเวลากิจกรรมที่บันทึกไว้ในตารางเวลา';

  /// สร้างช่องของรูปแบบที่ใช้อยู่ แล้วลบช่องอื่นทิ้งเพื่อไม่ให้รกหน้าตั้งค่าของระบบ
  static Future<void> _prepareChannel(AppSettings settings) async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final activeId = channelIdFor(settings);
    for (final id in _allChannelIds) {
      if (id != activeId) await android.deleteNotificationChannel(channelId: id);
    }

    await android.createNotificationChannel(AndroidNotificationChannel(
      activeId,
      _channelName(settings),
      description: _channelDescription,
      // สูงพอให้เด้งเป็นป๊อปอัป (heads-up) ทับหน้าจอที่ผู้ใช้เปิดอยู่
      importance: Importance.high,
      playSound: settings.soundEnabled,
      sound: settings.soundEnabled ? _soundResource : null,
      enableVibration: settings.vibrationEnabled,
      vibrationPattern: settings.vibrationEnabled ? _vibrationPattern : null,
    ));
  }

  static NotificationDetails _detailsFor(AppSettings settings) => NotificationDetails(
        android: AndroidNotificationDetails(
          channelIdFor(settings),
          _channelName(settings),
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: settings.soundEnabled,
          sound: settings.soundEnabled ? _soundResource : null,
          enableVibration: settings.vibrationEnabled,
          vibrationPattern: settings.vibrationEnabled ? _vibrationPattern : null,
          // บอกระบบว่านี่คือการเตือนตามเวลา เพื่อให้จัดลำดับและแสดงบนหน้าจอล็อกได้ถูกต้อง
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          // ไอคอนแถบสถานะต้องเป็นภาพขาวล้วนโปร่งใส ไม่ใช่ไอคอนแอปสี (Android จะตัดเป็นเงา)
          icon: 'ic_notification',
          color: const Color(0xFF5B57E8),
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
    await _prepareChannel(settings);

    final details = _detailsFor(settings);
    var scheduled = await _scheduleWaterReminders(settings, details);
    scheduled += await _scheduleBackupReminder(settings, details);
    if (!settings.scheduleRemindersEnabled) return scheduled;

    final events = ScheduleRepository().getAll();
    for (var i = 0; i < events.length; i++) {
      final when = _nextOccurrence(events[i], settings.remindMinutesBefore);
      if (when == null) continue;

      await _plugin.zonedSchedule(
        id: i,
        scheduledDate: when,
        title: events[i].title,
        body: bodyFor(events[i], settings.remindMinutesBefore),
        payload: events[i].id, // กดแล้วเปิดป๊อปอัปของกิจกรรมนี้
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // ประจำสัปดาห์ = ซ้ำทุกสัปดาห์ในวัน+เวลาเดียวกัน / เฉพาะวันที่ = ครั้งเดียว
        matchDateTimeComponents: events[i].isOneOff ? null : DateTimeComponents.dayOfWeekAndTime,
      );
      scheduled++;
    }
    return scheduled;
  }

  /// id ของการเตือนสำรองข้อมูล (ครั้งเดียว ตั้งใหม่ทุกครั้งที่ sync)
  static const _backupReminderId = 7500;

  /// เตือนให้สำรองข้อมูลเมื่อครบกำหนด — ข้อมูลอยู่ในเครื่องอย่างเดียว หายแล้วกู้ไม่ได้
  static Future<int> _scheduleBackupReminder(AppSettings settings, NotificationDetails details) async {
    final at = BackupReminder.nextReminderAt(settings);
    if (at == null) return 0;

    await _plugin.zonedSchedule(
      id: _backupReminderId,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      title: 'สำรองข้อมูล LifePlan',
      body: 'ข้อมูลทั้งหมดอยู่ในเครื่องนี้เท่านั้น — เปิดโปรไฟล์ → สำรอง & กู้คืนข้อมูล',
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return 1;
  }

  /// ช่วง id ของการเตือนดื่มน้ำ — แยกจากตารางเวลา (0..จำนวนกิจกรรม) และจากการเลื่อนเตือน (5000+)
  static const _waterIdBase = 7000;

  /// เตือนดื่มน้ำเป็นการแจ้งเตือนรายวันตรง ๆ ไม่ผ่านตารางเวลา (กันตารางรก)
  ///
  /// เป็นอิสระจากสวิตช์ "เตือนตามตารางเวลา" — ผู้ใช้เปิดเฉพาะเตือนน้ำอย่างเดียวได้
  static Future<int> _scheduleWaterReminders(AppSettings settings, NotificationDetails details) async {
    final times = settings.waterReminderTimes;
    var scheduled = 0;
    for (var i = 0; i < times.length; i++) {
      final when = nextDailyOccurrence(times[i]);
      if (when == null) continue;

      await _plugin.zonedSchedule(
        id: _waterIdBase + i,
        scheduledDate: when,
        title: 'ถึงเวลาดื่มน้ำ',
        body: 'จิบสักแก้วนะ แล้วกดบันทึกในหน้าโภชนาการได้เลย',
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // ซ้ำทุกวันในเวลาเดิม
        matchDateTimeComponents: DateTimeComponents.time,
      );
      scheduled++;
    }
    return scheduled;
  }

  /// เวลาถัดไปของ "HH:mm" รายวัน (วันนี้ถ้ายังไม่ถึง ไม่งั้นพรุ่งนี้)
  @visibleForTesting
  static tz.TZDateTime? nextDailyOccurrence(String hhmm, {tz.TZDateTime? now}) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    final current = now ?? tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, current.year, current.month, current.day, hour, minute);
    if (!when.isAfter(current)) when = when.add(const Duration(days: 1));
    return when;
  }

  /// ช่วง id ของการเตือนซ้ำ — ต้องไม่ชนกับ id ของตารางประจำสัปดาห์ (0..จำนวนกิจกรรม)
  /// และไม่ชนกับการแจ้งเตือนทดสอบ (9999)
  static const _snoozeIdBase = 5000;

  /// เลื่อนเตือนกิจกรรมนี้ออกไปอีก [delay] — ตั้งเป็นการแจ้งเตือนของระบบ
  /// เพื่อให้ยังดังแม้ผู้ใช้ปิดแอปไปก่อนครบเวลา
  static Future<void> snooze(ScheduleEvent event, Duration delay) async {
    await init();
    final settings = AppSettingsRepository().get();
    await _prepareChannel(settings);

    await _plugin.zonedSchedule(
      id: _snoozeIdBase + event.id.hashCode.abs() % 1000,
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      title: event.title,
      body: 'เตือนอีกครั้ง — ${event.time}${event.subtitle == null ? '' : ' • ${event.subtitle}'}',
      payload: event.id,
      notificationDetails: _detailsFor(settings),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @visibleForTesting
  static String bodyFor(ScheduleEvent event, int minutesBefore) {
    final head = minutesBefore == 0 ? 'ถึงเวลา ${event.time}' : 'อีก $minutesBefore นาที (${event.time})';
    return event.subtitle == null ? head : '$head • ${event.subtitle}';
  }

  /// เวลาที่จะเตือนครั้งถัดไปของกิจกรรมนี้ (ในอนาคตเสมอ) — นัดหมายเฉพาะวันที่ที่เลยไปแล้วได้ null
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

    final date = event.date;
    if (date != null) {
      final remindAt = tz.TZDateTime(tz.local, date.year, date.month, date.day, hour, minute)
          .subtract(Duration(minutes: minutesBefore));
      return remindAt.isAfter(current) ? remindAt : null;
    }

    // หาเวลา "เริ่มกิจกรรม" ครั้งถัดไปก่อน แล้วค่อยลบเวลาเตือนล่วงหน้าทีหลัง
    // (ลบก่อนจะเพี้ยนเมื่อการเตือนข้ามเที่ยงคืนไปอยู่คนละวันกับตัวกิจกรรม)
    var start = tz.TZDateTime(tz.local, current.year, current.month, current.day, hour, minute);
    start = start.add(Duration(days: (event.weekday - start.weekday + 7) % 7));

    var remindAt = start.subtract(Duration(minutes: minutesBefore));
    if (!remindAt.isAfter(current)) remindAt = remindAt.add(const Duration(days: 7));
    return remindAt;
  }

  /// แจ้งเตือนทดสอบทันที เพื่อให้ผู้ใช้เห็น (และได้ยิน) ว่าตั้งค่าไว้ถูกแล้วจริง
  static Future<void> showTestNotification() async {
    await init();
    final settings = AppSettingsRepository().get();
    await _prepareChannel(settings);
    await _plugin.show(
      id: 9999,
      title: 'LifePlan พร้อมเตือนคุณแล้ว',
      body: settings.soundEnabled
          ? 'ถ้าได้ยินเสียงนี้ แปลว่าการแจ้งเตือนทำงานปกติ'
          : 'ถ้าเห็นข้อความนี้ แปลว่าการแจ้งเตือนทำงานปกติ (ตอนนี้ปิดเสียงไว้)',
      notificationDetails: _detailsFor(settings),
    );
  }

  /// จำนวนการเตือนที่ตั้งค้างไว้ในระบบตอนนี้
  static Future<int> pendingCount() async {
    await init();
    return (await _plugin.pendingNotificationRequests()).length;
  }
}
