import '../models/client.dart';
import '../models/finance_transaction.dart';
import '../models/goal_settings.dart';
import '../models/life_category.dart';
import '../models/sleep_entry.dart';
import '../models/work_task.dart';
import 'repositories/client_repository.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/finance_repository.dart';
import 'repositories/goal_settings_repository.dart';
import 'repositories/meal_repository.dart';
import 'repositories/skill_track_repository.dart';
import 'repositories/sleep_repository.dart';
import 'repositories/water_repository.dart';
import 'repositories/work_task_repository.dart';

/// Derives the per-category and overall progress percentages shown on the
/// Dashboard and Progress screens directly from what's stored in Hive, so
/// the numbers always reflect real data instead of a hardcoded snapshot.
class Insights {
  Insights._();

  static Map<LifeCategory, int> categoryScores() {
    final goals = GoalSettingsRepository().get();

    final exerciseItems = ExerciseRepository().getAll();
    final exerciseScore = exerciseItems.isEmpty
        ? 0
        : ((exerciseItems.where((e) => e.isDone).length / goals.exerciseWeeklyTarget) * 100).clamp(0, 100).round();

    final tasks = WorkTaskRepository().getAll();
    final workScore = tasks.isEmpty ? 0 : ((tasks.where((t) => t.status == TaskStatus.done).length / tasks.length) * 100).round();

    final clients = ClientRepository().getAll();
    final crmScore = clients.isEmpty ? 0 : ((clients.where((c) => c.stage == ClientStage.closedWon).length / clients.length) * 100).round();

    final txs = FinanceRepository().getAll();
    final savings = txs
        .where((t) => t.type == TransactionType.expense && t.category == ExpenseCategory.investmentSaving)
        .fold<double>(0, (s, t) => s + t.amount);
    final financeScore = ((savings / goals.savingTarget) * 100).clamp(0, 100).round();

    final nutrition = nutritionScore(goals: goals);
    final sleep = sleepScore(goals: goals);

    final skills = SkillTrackRepository().getAll();
    final learningScore = skills.isEmpty ? 0 : (skills.fold<int>(0, (s, t) => s + t.progressPercent) / skills.length).round();

    return {
      LifeCategory.exercise: exerciseScore,
      LifeCategory.nutrition: nutrition,
      LifeCategory.sleep: sleep,
      LifeCategory.work: workScore,
      LifeCategory.crm: crmScore,
      LifeCategory.finance: financeScore,
      LifeCategory.learning: learningScore,
    };
  }

  /// คะแนนโภชนาการของวันนี้ — เฉลี่ยจาก 4 ด้านที่วัดได้จริง:
  /// แคลอรี่, โปรตีน, น้ำดื่ม และการคุมน้ำตาลไม่ให้เกินเพดาน
  /// (น้ำตาลเกินเพดานยิ่งมาก คะแนนส่วนนี้ยิ่งลด)
  static int nutritionScore({GoalSettings? goals, DateTime? day}) {
    final g = goals ?? GoalSettingsRepository().get();
    final target = day ?? DateTime.now();

    final totals = MealRepository().totalsForDay(target);
    final waterMl = WaterRepository().getForDay(target).milliliters;
    if (totals.isEmpty && waterMl == 0) return 0;

    final sugarRatio = totals.sugar <= g.sugarLimit ? 1.0 : _ratio(g.sugarLimit, totals.sugar);
    final parts = [
      _ratio(totals.calories.toDouble(), g.calorieTarget.toDouble()),
      _ratio(totals.protein, g.proteinTarget),
      _ratio(waterMl.toDouble(), g.waterTargetMl.toDouble()),
      sugarRatio,
    ];

    return ((parts.reduce((a, b) => a + b) / parts.length) * 100).round();
  }

  /// คะแนนคุณภาพการนอนของคืนล่าสุด — เฉลี่ยจาก 3 ด้าน:
  /// นอนได้ครบเป้าไหม, ผู้ใช้ให้คะแนนคุณภาพเท่าไร และตื่นกลางดึกบ่อยแค่ไหน
  ///
  /// ยังไม่ได้บันทึกการนอนของคืนนั้น = 0 (เหมือนโมดูลอื่นที่ยังไม่มีข้อมูล)
  static int sleepScore({GoalSettings? goals, DateTime? day}) {
    final entry = SleepRepository().getForDay(day ?? DateTime.now());
    if (entry == null) return 0;
    return scoreOfNight(entry, (goals ?? GoalSettingsRepository().get()).sleepTargetMinutes);
  }

  /// แยกออกมาให้คำนวณคะแนนของคืนใด ๆ ได้โดยไม่ต้องแตะ Hive (หน้าจอ/เทสเรียกตรง ๆ)
  static int scoreOfNight(SleepEntry entry, int targetMinutes) {
    // ตื่นกลางดึกครั้งละ -15% แต่ไม่ให้ต่ำกว่า 40% เพราะยังนับว่าได้นอน
    final awakeningRatio = (1 - 0.15 * entry.awakenings).clamp(0.4, 1.0).toDouble();
    final parts = [
      _ratio(entry.durationMinutes.toDouble(), targetMinutes.toDouble()),
      entry.quality.weight,
      awakeningRatio,
    ];
    return ((parts.reduce((a, b) => a + b) / parts.length) * 100).round();
  }

  /// สัดส่วน 0–1 ที่กันหารด้วยศูนย์ไว้ เผื่อเป้าหมายถูกตั้งเป็น 0
  static double _ratio(double value, double target) {
    if (target <= 0) return 0;
    return (value / target).clamp(0, 1).toDouble();
  }

  static int overallScore(Map<LifeCategory, int> scores) {
    if (scores.isEmpty) return 0;
    return (scores.values.reduce((a, b) => a + b) / scores.length).round();
  }
}
