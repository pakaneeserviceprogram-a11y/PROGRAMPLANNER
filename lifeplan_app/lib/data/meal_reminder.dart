import '../models/life_category.dart';
import '../models/schedule_event.dart';
import 'repositories/schedule_repository.dart';

/// มื้อที่ตั้งเตือนได้ (เตือนเป็นเวลาประจำทุกวัน ไม่ผูกกับมื้อที่บันทึกไว้)
enum MealSlot { breakfast, lunch, dinner }

extension MealSlotX on MealSlot {
  String get label => switch (this) {
        MealSlot.breakfast => 'มื้อเช้า',
        MealSlot.lunch => 'มื้อกลางวัน',
        MealSlot.dinner => 'มื้อเย็น',
      };

  String get defaultTime => switch (this) {
        MealSlot.breakfast => '07:30',
        MealSlot.lunch => '12:00',
        MealSlot.dinner => '18:30',
      };
}

/// เตือนมื้ออาหาร — เขียนเป็นกิจกรรมประจำสัปดาห์ครบ 7 วันต่อมื้อ (id คงที่)
/// จึงได้ทั้งการแจ้งเตือนของระบบและป๊อปอัปในแอปโดยไม่ต้องเพิ่มกลไกใหม่
/// และผู้ใช้ยังเห็น/แก้/ลบมันเองในหน้าตารางเวลาได้
///
/// ดื่มน้ำไม่ได้ใช้วิธีนี้ เพราะเตือนทุก 2 ชม. = 42 รายการต่อสัปดาห์ จะรกตาราง
/// (ดู `AppSettings.waterRemindersEnabled` + `NotificationService`)
class MealReminder {
  MealReminder._();

  static const subtitle = 'เตือนมื้ออาหาร';

  static String seriesIdOf(MealSlot slot) => 'meal-reminder-${slot.name}';

  static String idFor(MealSlot slot, int weekday) => '${seriesIdOf(slot)}-$weekday';

  /// เวลาที่ตั้งเตือนของมื้อนี้ — ยังไม่ได้เปิด = null
  static String? timeOf(ScheduleRepository repo, MealSlot slot) {
    final key = seriesIdOf(slot);
    for (final e in repo.getAll()) {
      if (e.seriesKey == key) return e.time;
    }
    return null;
  }

  static bool isOn(ScheduleRepository repo, MealSlot slot) => timeOf(repo, slot) != null;

  /// เปิด/แก้เวลาของมื้อนั้น — เขียนทับ id เดิมทั้ง 7 วัน จึงไม่มีรายการค้าง
  static Future<void> apply(ScheduleRepository repo, MealSlot slot, String time) async {
    for (var weekday = 1; weekday <= 7; weekday++) {
      await repo.put(ScheduleEvent(
        id: idFor(slot, weekday),
        time: time,
        weekday: weekday,
        title: slot.label,
        subtitle: subtitle,
        category: LifeCategory.nutrition,
        seriesId: seriesIdOf(slot),
      ));
    }
  }

  static Future<void> remove(ScheduleRepository repo, MealSlot slot) async {
    for (var weekday = 1; weekday <= 7; weekday++) {
      await repo.delete(idFor(slot, weekday));
    }
  }
}
