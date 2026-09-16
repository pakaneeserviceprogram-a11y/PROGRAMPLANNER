import 'package:hive_flutter/hive_flutter.dart';

/// Central place for Hive box names + startup init. Every model is stored as
/// a plain `Map<String, dynamic>` inside a `Box<Map>` — no generated
/// TypeAdapters needed, which keeps the local-database layer simple and easy
/// to extend as the schema in DATA_MODEL.md grows.
class HiveBoxes {
  HiveBoxes._();

  static const userProfile = 'user_profile';
  static const workTasks = 'work_tasks';
  static const exerciseItems = 'exercise_items';
  static const mealEntries = 'meal_entries';
  static const waterLogs = 'water_logs';
  static const sleepEntries = 'sleep_entries';
  static const clients = 'clients';
  static const weeklyReports = 'weekly_reports';
  static const financeTransactions = 'finance_transactions';
  static const skillTracks = 'skill_tracks';
  static const scheduleEvents = 'schedule_events';
  static const learningStreak = 'learning_streak';
  static const goalSettings = 'goal_settings';
  static const appSettings = 'app_settings';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(userProfile),
      Hive.openBox<Map>(workTasks),
      Hive.openBox<Map>(exerciseItems),
      Hive.openBox<Map>(mealEntries),
      Hive.openBox<Map>(waterLogs),
      Hive.openBox<Map>(sleepEntries),
      Hive.openBox<Map>(clients),
      Hive.openBox<Map>(weeklyReports),
      Hive.openBox<Map>(financeTransactions),
      Hive.openBox<Map>(skillTracks),
      Hive.openBox<Map>(scheduleEvents),
      Hive.openBox<Map>(learningStreak),
      Hive.openBox<Map>(goalSettings),
      Hive.openBox<Map>(appSettings),
    ]);
  }
}
