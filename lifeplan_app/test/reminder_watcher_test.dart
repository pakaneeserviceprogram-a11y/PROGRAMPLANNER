import 'package:flutter_test/flutter_test.dart';

import 'package:lifeplan_app/data/reminder_watcher.dart';
import 'package:lifeplan_app/models/app_settings.dart';
import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';

/// ตัวจับเวลาของป๊อปอัปในแอป — จุดที่ผิดง่ายคือการหา "รอบเตือนล่าสุด"
/// ย้อนหลัง ซึ่งต้องข้ามเที่ยงคืน/ข้ามสัปดาห์ได้ถูกต้อง
void main() {
  const event = ScheduleEvent(
    id: 'e1',
    time: '09:00',
    weekday: DateTime.wednesday,
    title: 'ประชุม',
    category: LifeCategory.work,
  );

  // 2026-09-16 คือวันพุธ
  DateTime at(int day, int hour, int minute) => DateTime(2026, 9, day, hour, minute);

  const enabled = AppSettings(scheduleRemindersEnabled: true, remindMinutesBefore: 10);

  group('lastRemindAtOrBefore', () {
    test('คืนรอบของวันนี้เมื่อเลยเวลาเตือนมาแล้ว', () {
      expect(ReminderWatcher.lastRemindAtOrBefore(event, 10, at(16, 12, 0)), at(16, 8, 50));
    });

    test('ยังไม่ถึงเวลาเตือนของวันนี้ ให้ถอยไปรอบสัปดาห์ก่อน', () {
      expect(ReminderWatcher.lastRemindAtOrBefore(event, 10, at(16, 7, 0)), at(9, 8, 50));
    });

    test('วันที่ยังไม่ถึงวันของกิจกรรม ให้ถอยไปวันนั้นของสัปดาห์ก่อน', () {
      // 2026-09-14 วันจันทร์ — พุธล่าสุดคือ 2026-09-09
      expect(ReminderWatcher.lastRemindAtOrBefore(event, 0, at(14, 22, 0)), at(9, 9, 0));
    });

    test('เตือนล่วงหน้าข้ามเที่ยงคืนได้ (กิจกรรมเช้ามืด)', () {
      const early = ScheduleEvent(
        id: 'e2',
        time: '00:15',
        weekday: DateTime.thursday,
        title: 'ตื่นเดินทาง',
        category: LifeCategory.work,
      );
      // กิจกรรมพฤหัส 17 ก.ย. 00:15 เตือนก่อน 30 นาที = คืนวันพุธ 16 ก.ย. 23:45
      expect(ReminderWatcher.lastRemindAtOrBefore(early, 30, at(17, 8, 0)), at(16, 23, 45));
    });

    test('เวลาที่อ่านไม่ออกจะถูกข้าม แทนที่จะพังทั้งหมด', () {
      const broken = ScheduleEvent(
        id: 'e3',
        time: 'ไม่ใช่เวลา',
        weekday: DateTime.friday,
        title: 'เสีย',
        category: LifeCategory.work,
      );
      expect(ReminderWatcher.lastRemindAtOrBefore(broken, 0, at(16, 8, 0)), isNull);
    });
  });

  group('dueBetween', () {
    test('เจอกิจกรรมที่เวลาเตือนตกอยู่ในช่วงที่เพิ่งผ่านไป', () {
      final due = ReminderWatcher.dueBetween(
        const [event],
        enabled,
        from: at(16, 8, 49),
        to: at(16, 8, 50),
      );
      expect(due, hasLength(1));
      expect(due.first.event.id, 'e1');
      expect(due.first.remindAt, at(16, 8, 50));
      expect(due.first.minutesBefore, 10);
    });

    test('ยังไม่ถึงเวลาเตือน ยังไม่เด้ง', () {
      expect(
        ReminderWatcher.dueBetween(const [event], enabled, from: at(16, 8, 48), to: at(16, 8, 49)),
        isEmpty,
      );
    });

    test('เลยช่วงที่ตรวจไปแล้ว ไม่เด้งซ้ำ', () {
      expect(
        ReminderWatcher.dueBetween(const [event], enabled, from: at(16, 9, 0), to: at(16, 9, 30)),
        isEmpty,
      );
    });

    test('หลายกิจกรรมพร้อมกัน เรียงตามเวลาเตือน', () {
      const later = ScheduleEvent(
        id: 'e4',
        time: '09:05',
        weekday: DateTime.wednesday,
        title: 'ตามด้วยโทรหาลูกค้า',
        category: LifeCategory.crm,
      );
      final due = ReminderWatcher.dueBetween(
        const [later, event],
        enabled,
        from: at(16, 8, 49),
        to: at(16, 9, 0),
      );
      expect(due.map((d) => d.event.id), ['e1', 'e4']);
    });

    test('คีย์ของแต่ละรอบต่างกัน เพื่อให้สัปดาห์หน้ายังเด้งได้อีก', () {
      final thisWeek = ReminderWatcher.dueBetween(
        const [event],
        enabled,
        from: at(16, 8, 49),
        to: at(16, 8, 50),
      ).single;
      final nextWeek = ReminderWatcher.dueBetween(
        const [event],
        enabled,
        from: at(23, 8, 49),
        to: at(23, 8, 50),
      ).single;
      expect(thisWeek.occurrenceKey, isNot(nextWeek.occurrenceKey));
    });
  });
}
