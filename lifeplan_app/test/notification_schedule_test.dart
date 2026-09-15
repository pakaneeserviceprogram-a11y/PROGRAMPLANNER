import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:lifeplan_app/data/notifications.dart';
import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';

/// ทดสอบเฉพาะการคำนวณ "เวลาเตือนครั้งถัดไป" ซึ่งเป็นส่วนที่ผิดพลาดง่ายสุด
/// (ตัว plugin เองต้องมีเครื่องจริงถึงจะทดสอบได้ — ทดสอบด้วยมือบน emulator แล้ว)
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));
  });

  const event = ScheduleEvent(
    id: 'e1',
    time: '09:00',
    weekday: DateTime.wednesday,
    title: 'ประชุม',
    category: LifeCategory.work,
  );

  tz.TZDateTime at(int day, int hour, int minute) => tz.TZDateTime(tz.local, 2026, 9, day, hour, minute);

  test('เตือนล่วงหน้าตามนาทีที่ตั้งไว้ ในวันเดียวกันถ้ายังไม่ถึงเวลา', () {
    // 2026-09-16 คือวันพุธ เวลา 07:00 — ยังไม่ถึง 08:50 (เตือนก่อน 10 นาที)
    final next = NotificationService.nextOccurrenceOf(event, 10, now: at(16, 7, 0))!;
    expect(next, at(16, 8, 50));
    expect(next.weekday, DateTime.wednesday);
  });

  test('ถ้าเลยเวลาเตือนของวันนี้ไปแล้ว ให้ข้ามไปสัปดาห์หน้า', () {
    final next = NotificationService.nextOccurrenceOf(event, 10, now: at(16, 12, 0))!;
    expect(next, at(23, 8, 50)); // พุธถัดไป
  });

  test('ถ้าวันนี้ยังไม่ถึงวันของกิจกรรม ให้เลื่อนไปวันนั้นในสัปดาห์นี้', () {
    // 2026-09-14 วันจันทร์
    final next = NotificationService.nextOccurrenceOf(event, 0, now: at(14, 22, 0))!;
    expect(next, at(16, 9, 0));
  });

  test('เตือนล่วงหน้าข้ามเที่ยงคืนได้ (กิจกรรมเช้ามืด)', () {
    const early = ScheduleEvent(
      id: 'e2',
      time: '00:15',
      weekday: DateTime.thursday,
      title: 'ตื่นเดินทาง',
      category: LifeCategory.work,
    );
    // เตือนก่อน 30 นาที = คืนวันพุธ 23:45
    final next = NotificationService.nextOccurrenceOf(early, 30, now: at(14, 8, 0))!;
    expect(next, at(16, 23, 45));
    expect(next.weekday, DateTime.wednesday);
  });

  test('เวลาที่อ่านไม่ออกจะไม่ถูกตั้งเตือน แทนที่จะพังทั้งหมด', () {
    const broken = ScheduleEvent(
      id: 'e3',
      time: 'ไม่ใช่เวลา',
      weekday: DateTime.friday,
      title: 'เสีย',
      category: LifeCategory.work,
    );
    expect(NotificationService.nextOccurrenceOf(broken, 0, now: at(14, 8, 0)), isNull);
  });
}
