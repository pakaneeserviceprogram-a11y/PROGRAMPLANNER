import '../models/goal_settings.dart';
import '../models/life_category.dart';
import '../models/schedule_event.dart';
import '../models/sleep_entry.dart';
import 'repositories/schedule_repository.dart';

/// เตือน "ถึงเวลาเข้านอน" อัตโนมัติ — คำนวณเวลาจาก **เวลาตื่นเฉลี่ยจริง** ลบด้วยเป้าเวลานอน
/// แล้วสร้างเป็นกิจกรรมประจำสัปดาห์ครบ 7 วันในตารางเวลา จึงได้ทั้งการแจ้งเตือนของระบบ
/// และป๊อปอัปในแอปฟรี ๆ (ดู `NotificationService` / `ReminderWatcher`)
///
/// ใช้ id คงที่ต่อวัน เปิด-ปิด/อัปเดตเวลาได้โดยไม่สร้างรายการซ้ำ และผู้ใช้ยังแก้/ลบเองในหน้าตารางเวลาได้
class BedtimeReminder {
  BedtimeReminder._();

  static const title = 'เตรียมตัวเข้านอน';
  static const subtitle = 'ตั้งอัตโนมัติจากเป้าเวลานอน';
  static const seriesId = 'bedtime-auto';

  /// เวลาตื่นก่อนช่วงนี้ถือเป็นการตื่น "ดึกมาก" ของคืนก่อนหน้า ต้องบวก 24 ชม. ก่อนเฉลี่ย
  /// ไม่งั้นตื่น 01:00 กับ 06:00 จะเฉลี่ยออกมากลางดึก
  static const _wakeWrapBefore = 3 * 60;

  static String idFor(int weekday) => '$seriesId-$weekday';

  static String formatMinutes(int minutes) {
    final m = minutes % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  /// เวลาตื่นเฉลี่ยของคืนที่บันทึกไว้ (นาทีจากเที่ยงคืน) — ไม่มีข้อมูล = null
  static int? averageWakeMinutes(Iterable<SleepEntry> nights) {
    final values = <int>[];
    for (final n in nights) {
      final wake = SleepEntry.minutesOf(n.wakeTime);
      if (wake != null) values.add(wake < _wakeWrapBefore ? wake + 1440 : wake);
    }
    if (values.isEmpty) return null;
    return (values.reduce((a, b) => a + b) / values.length).round() % 1440;
  }

  /// เวลาเข้านอนที่แนะนำ "HH:mm" (เวลาตื่นเฉลี่ย − เป้าเวลานอน) — ยังไม่มีบันทึกการนอน = null
  static String? suggestedTime(Iterable<SleepEntry> nights, GoalSettings goals) {
    final wake = averageWakeMinutes(nights);
    if (wake == null) return null;
    return formatMinutes((wake - goals.sleepTargetMinutes) % 1440);
  }

  /// เวลาที่ตั้งเตือนไว้อยู่ตอนนี้ — ยังไม่ได้เปิด = null
  static String? currentTime(ScheduleRepository repo) {
    for (final e in repo.getAll()) {
      if (e.seriesKey == seriesId) return e.time;
    }
    return null;
  }

  static bool isOn(ScheduleRepository repo) => currentTime(repo) != null;

  /// เปิด/อัปเดตเวลา — เขียนทับรายการเดิมทั้ง 7 วัน (id เดิม จึงไม่มีรายการค้าง)
  static Future<void> apply(ScheduleRepository repo, String time) async {
    for (var weekday = 1; weekday <= 7; weekday++) {
      await repo.put(ScheduleEvent(
        id: idFor(weekday),
        time: time,
        weekday: weekday,
        title: title,
        subtitle: subtitle,
        category: LifeCategory.sleep,
        seriesId: seriesId,
      ));
    }
  }

  static Future<void> remove(ScheduleRepository repo) async {
    for (var weekday = 1; weekday <= 7; weekday++) {
      await repo.delete(idFor(weekday));
    }
  }
}
