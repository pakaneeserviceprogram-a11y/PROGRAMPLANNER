import '../models/client.dart';
import '../models/exercise_item.dart';
import '../models/finance_transaction.dart';
import '../models/life_category.dart';
import '../models/meal_entry.dart';
import '../models/schedule_event.dart';
import '../models/skill_track.dart';
import '../models/water_log.dart';
import '../models/weekly_report.dart';
import '../models/work_task.dart';
import 'repositories/app_settings_repository.dart';
import 'repositories/client_repository.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/finance_repository.dart';
import 'repositories/meal_repository.dart';
import 'repositories/schedule_repository.dart';
import 'repositories/skill_track_repository.dart';
import 'repositories/water_repository.dart';
import 'repositories/weekly_report_repository.dart';
import 'repositories/work_task_repository.dart';

/// Populates every box with sample data the first time the app runs, so a
/// fresh install still shows a believable LifePlan instead of empty
/// screens. Real edits from then on persist in Hive and this never runs
/// again (each box is only seeded while still empty).
class SeedData {
  SeedData._();

  static Future<void> seedIfEmpty() async {
    // ผู้ใช้กด "ล้างข้อมูล" เพื่อเริ่มเก็บประวัติใหม่แล้ว — ปล่อยให้แอปว่างตามนั้น
    if (AppSettingsRepository().get().sampleDataDisabled) return;

    await _seedExercise();
    await _seedNutrition();
    await _seedWork();
    await _seedClients();
    await _seedWeeklyReports();
    await _seedFinance();
    await _seedSkills();
    await _seedSchedule();
  }

  static Future<void> _seedExercise() async {
    final repo = ExerciseRepository();
    if (repo.getAll().isNotEmpty) return;
    const items = [
      ExercisePlanItem(id: 'e1', title: 'จันทร์ • วิ่ง', type: ExerciseType.run, dayLabel: 'จันทร์', durationMinutes: 30, isDone: true),
      ExercisePlanItem(id: 'e2', title: 'อังคาร • เวทเทรนนิ่ง', type: ExerciseType.strength, dayLabel: 'อังคาร', durationMinutes: 45, isDone: true),
      ExercisePlanItem(id: 'e3', title: 'พุธ • พักผ่อน', type: ExerciseType.stretch, dayLabel: 'พุธ', durationMinutes: 10),
      ExercisePlanItem(id: 'e4', title: 'พฤหัสบดี • ปั่นจักรยาน', type: ExerciseType.cycle, dayLabel: 'พฤหัสบดี', durationMinutes: 40, isToday: true),
      ExercisePlanItem(id: 'e5', title: 'ศุกร์ • ว่ายน้ำ', type: ExerciseType.swim, dayLabel: 'ศุกร์', durationMinutes: 30),
      ExercisePlanItem(id: 'e6', title: 'เสาร์ • เดินเขา', type: ExerciseType.hike, dayLabel: 'เสาร์', durationMinutes: 90),
    ];
    for (final i in items) {
      await repo.put(i);
    }
  }

  static Future<void> _seedNutrition() async {
    final repo = MealRepository();
    if (repo.getAll().isEmpty) {
      final today = DateTime.now();
      final meals = [
        MealEntry(
          id: 'm1',
          title: 'ข้าวต้มปลา + ไข่ต้ม',
          type: MealType.breakfast,
          time: '07:00',
          date: today,
          calories: 420,
          proteinGrams: 26,
          carbGrams: 52,
          fatGrams: 9,
          sugarGrams: 3,
          vitamins: const [Vitamin.b, Vitamin.d],
        ),
        MealEntry(
          id: 'm2',
          title: 'กล้วยหอม 1 ผล',
          type: MealType.snack,
          time: '09:30',
          date: today,
          calories: 105,
          proteinGrams: 1.3,
          carbGrams: 27,
          fatGrams: 0.4,
          sugarGrams: 14,
          vitamins: const [Vitamin.b, Vitamin.c],
          workoutTiming: WorkoutTiming.preWorkout,
        ),
        MealEntry(
          id: 'm3',
          title: 'ข้าวกล้องอกไก่ผัดผักรวม',
          type: MealType.lunch,
          time: '12:15',
          date: today,
          calories: 610,
          proteinGrams: 42,
          carbGrams: 70,
          fatGrams: 14,
          sugarGrams: 6,
          vitamins: const [Vitamin.a, Vitamin.c, Vitamin.k],
          workoutTiming: WorkoutTiming.postWorkout,
        ),
      ];
      for (final m in meals) {
        await repo.put(m);
      }
    }

    final waterRepo = WaterRepository();
    if (waterRepo.getAll().isEmpty) {
      await waterRepo.put(WaterLog(date: DateTime.now(), milliliters: 4 * WaterLog.glassMl));
    }
  }

  static Future<void> _seedWork() async {
    final repo = WorkTaskRepository();
    if (repo.getAll().isNotEmpty) return;
    const items = [
      WorkTask(id: 'w1', title: 'สรุปยอดขายประจำเดือน', status: TaskStatus.todo, priority: TaskPriority.urgent, dueLabel: 'กำหนดส่ง 17:00'),
      WorkTask(id: 'w2', title: 'เตรียมเอกสารประชุมทีม', status: TaskStatus.todo, priority: TaskPriority.normal, dueLabel: '09:00'),
      WorkTask(id: 'w3', title: 'ตอบอีเมลลูกค้าที่ค้างไว้', status: TaskStatus.todo, priority: TaskPriority.low),
      WorkTask(id: 'w4', title: 'จัดทำรายงานผลการดำเนินงานไตรมาส 3', status: TaskStatus.inProgress, priority: TaskPriority.normal, progressPercent: 55),
      WorkTask(id: 'w5', title: 'เช็คอีเมลตอนเช้า', status: TaskStatus.done, priority: TaskPriority.low),
    ];
    for (final i in items) {
      await repo.put(i);
    }
  }

  static Future<void> _seedClients() async {
    final repo = ClientRepository();
    if (repo.getAll().isNotEmpty) return;
    const items = [
      Client(id: 'c1', name: 'คุณสมชาย ใจดี', initials: 'สช', policyLabel: 'ประกันสุขภาพ • นัดพบวันนี้ 13:30', stage: ClientStage.followUp, premiumAmount: 42000),
      Client(id: 'c2', name: 'คุณพรทิพย์ วงศ์งาม', initials: 'พร', policyLabel: 'ประกันชีวิต • ส่งใบเสนอราคาแล้ว', stage: ClientStage.proposalSent, premiumAmount: 65000),
      Client(id: 'c3', name: 'คุณอนุชา ทองแดง', initials: 'อน', policyLabel: 'ประกันรถยนต์ • ปิดการขายแล้ว', stage: ClientStage.closedWon, premiumAmount: 38000),
      Client(id: 'c4', name: 'คุณมาลี ศรีสุข', initials: 'มล', policyLabel: 'ประกันสุขภาพ • ลูกค้าใหม่จาก Referral', stage: ClientStage.newLead, premiumAmount: 37000),
    ];
    for (final i in items) {
      await repo.put(i);
    }
  }

  /// รายงานผลงานประจำสัปดาห์ตัวอย่าง (สัปดาห์ที่ 29/4/67-5/5/67) เพื่อให้เห็น
  /// รูปแบบ P-A-S-R-F-N-T ที่ต้องส่งหัวหน้าตั้งแต่เปิดแอปครั้งแรก
  static Future<void> _seedWeeklyReports() async {
    final repo = WeeklyReportRepository();
    if (repo.getAll().isNotEmpty) return;
    await repo.put(WeeklyReport(
      weekStart: DateTime(2024, 4, 29), // = 29/4/2567
      ownerName: 'เอ๋',
      salesPremium: 60000,
      activities: const {
        ActivityCode.prospect: WeeklyActivity(count: 5),
        ActivityCode.appointment: WeeklyActivity(count: 3, note: 'ลูกค้าใหม่ 3'),
        ActivityCode.sales: WeeklyActivity(count: 2, note: 'ขาย Offline'),
        ActivityCode.referral: WeeklyActivity(count: 1),
        ActivityCode.followUp: WeeklyActivity(count: 2, note: 'ติดต่อทางไลน์ค่ะ'),
        ActivityCode.newMarket: WeeklyActivity(count: 1, note: 'ทักลูกค้าจากเพื่อนแนะนำค่ะ'),
        ActivityCode.team: WeeklyActivity(count: 0),
      },
    ));
  }

  static Future<void> _seedFinance() async {
    final repo = FinanceRepository();
    if (repo.getAll().isNotEmpty) return;
    final now = DateTime.now();
    final items = [
      FinanceTransaction(id: 't1', title: 'ข้าวกลางวัน', date: DateTime(now.year, now.month, now.day, 12, 30), amount: 120, type: TransactionType.expense, category: ExpenseCategory.food),
      FinanceTransaction(id: 't2', title: 'โอนเข้ากองทุนออม', date: now.subtract(const Duration(days: 1)), amount: 5000, type: TransactionType.expense, category: ExpenseCategory.investmentSaving),
      FinanceTransaction(id: 't3', title: 'ค่าคอมมิชชั่นประกัน', date: now.subtract(const Duration(days: 2)), amount: 14200, type: TransactionType.income),
      FinanceTransaction(id: 't4', title: 'ค่าเดินทางพบลูกค้า', date: now.subtract(const Duration(days: 2)), amount: 350, type: TransactionType.expense, category: ExpenseCategory.transport),
      FinanceTransaction(id: 't5', title: 'เงินเดือน', date: now.subtract(const Duration(days: 5)), amount: 45000, type: TransactionType.income),
      FinanceTransaction(id: 't6', title: 'ซื้อกองทุนรวม', date: now.subtract(const Duration(days: 6)), amount: 8000, type: TransactionType.expense, category: ExpenseCategory.investmentSaving),
    ];
    for (final i in items) {
      await repo.put(i);
    }
  }

  static Future<void> _seedSkills() async {
    final repo = SkillTrackRepository();
    if (repo.getAll().isNotEmpty) return;
    const items = [
      SkillTrack(id: 'sk1', name: 'ภาษาอังกฤษ', subtitle: 'ระดับ Intermediate', progressPercent: 56, isPrimary: true),
      SkillTrack(id: 'sk2', name: 'สกิลการลงทุน', subtitle: 'พื้นฐานหุ้นและกองทุนรวม', progressPercent: 38),
      SkillTrack(id: 'sk3', name: 'คณิตศาสตร์', subtitle: 'สถิติและความน่าจะเป็น', progressPercent: 22),
      SkillTrack(id: 'sk4', name: 'พัฒนาสมอง', subtitle: 'เกมฝึกความจำและสมาธิ', progressPercent: 70),
    ];
    for (final i in items) {
      await repo.put(i);
    }
  }

  static Future<void> _seedSchedule() async {
    final repo = ScheduleRepository();
    if (repo.getAll().isNotEmpty) return;
    // ตัวอย่างวันนี้ 5 รายการ + อีก 4 รายการกระจายในสัปดาห์ เพื่อให้มุมมองรายสัปดาห์มีข้อมูลให้ดู
    final today = DateTime.now().weekday;
    int dayAfter(int offset) => ((today - 1 + offset) % 7) + 1;
    final items = [
      ScheduleEvent(id: 's1', time: '06:00', weekday: today, title: 'วิ่งตอนเช้า', subtitle: 'สวนสาธารณะใกล้บ้าน • 30 นาที', category: LifeCategory.exercise),
      ScheduleEvent(id: 's2', time: '09:00', weekday: today, title: 'ประชุมทีมงานประจำ', subtitle: 'ห้องประชุม A • 09:00–12:00', category: LifeCategory.work),
      ScheduleEvent(id: 's3', time: '13:30', weekday: today, title: 'นัดพบลูกค้า คุณสมชาย', subtitle: 'นำเสนอแผนประกันสุขภาพ • 45 นาที', category: LifeCategory.crm),
      ScheduleEvent(id: 's4', time: '18:00', weekday: today, title: 'บันทึกรายรับ-รายจ่าย', subtitle: '10 นาที', category: LifeCategory.finance),
      ScheduleEvent(id: 's5', time: '20:00', weekday: today, title: 'เรียนภาษาอังกฤษ', subtitle: 'บทที่ 14 • Daily conversation • 20 นาที', category: LifeCategory.learning),
      ScheduleEvent(id: 's6', time: '06:00', weekday: dayAfter(1), title: 'เวทเทรนนิ่ง', subtitle: 'ฟิตเนส • 45 นาที', category: LifeCategory.exercise),
      ScheduleEvent(id: 's7', time: '10:00', weekday: dayAfter(2), title: 'ติดตามลูกค้าเก่า', subtitle: 'โทร 5 ราย • 1 ชั่วโมง', category: LifeCategory.crm),
      ScheduleEvent(id: 's8', time: '19:30', weekday: dayAfter(3), title: 'สรุปยอดขายประจำสัปดาห์', subtitle: '30 นาที', category: LifeCategory.finance),
      ScheduleEvent(id: 's9', time: '09:30', weekday: dayAfter(5), title: 'อ่านหนังสือ / คอร์สออนไลน์', subtitle: 'วันหยุด • 1 ชั่วโมง', category: LifeCategory.learning),
      ScheduleEvent(id: 's10', time: '07:00', weekday: today, title: 'มื้อเช้า', subtitle: 'โปรตีน + แป้งเชิงซ้อน • บันทึกโภชนาการ', category: LifeCategory.nutrition),
      ScheduleEvent(id: 's11', time: '12:00', weekday: today, title: 'มื้อกลางวัน', subtitle: 'เน้นผักและโปรตีน • เลี่ยงน้ำหวาน', category: LifeCategory.nutrition),
      ScheduleEvent(id: 's12', time: '18:30', weekday: today, title: 'มื้อเย็น', subtitle: 'มื้อเบา • ดื่มน้ำให้ครบ 2,000 มล.', category: LifeCategory.nutrition),
    ];
    for (final i in items) {
      await repo.put(i);
    }
  }
}
