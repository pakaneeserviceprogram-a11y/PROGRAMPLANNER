import '../models/client.dart';
import '../models/finance_transaction.dart';
import '../models/life_category.dart';
import '../models/work_task.dart';
import 'repositories/client_repository.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/finance_repository.dart';
import 'repositories/goal_settings_repository.dart';
import 'repositories/skill_track_repository.dart';
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

    final skills = SkillTrackRepository().getAll();
    final learningScore = skills.isEmpty ? 0 : (skills.fold<int>(0, (s, t) => s + t.progressPercent) / skills.length).round();

    return {
      LifeCategory.exercise: exerciseScore,
      LifeCategory.work: workScore,
      LifeCategory.crm: crmScore,
      LifeCategory.finance: financeScore,
      LifeCategory.learning: learningScore,
    };
  }

  static int overallScore(Map<LifeCategory, int> scores) {
    if (scores.isEmpty) return 0;
    return (scores.values.reduce((a, b) => a + b) / scores.length).round();
  }
}
