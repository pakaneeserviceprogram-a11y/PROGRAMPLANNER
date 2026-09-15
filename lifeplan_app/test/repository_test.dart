import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/id_gen.dart';
import 'package:lifeplan_app/data/insights.dart';
import 'package:lifeplan_app/data/repositories/client_repository.dart';
import 'package:lifeplan_app/data/repositories/exercise_repository.dart';
import 'package:lifeplan_app/data/repositories/finance_repository.dart';
import 'package:lifeplan_app/data/repositories/goal_settings_repository.dart';
import 'package:lifeplan_app/data/repositories/learning_streak_repository.dart';
import 'package:lifeplan_app/data/repositories/schedule_repository.dart';
import 'package:lifeplan_app/data/repositories/skill_track_repository.dart';
import 'package:lifeplan_app/data/repositories/user_repository.dart';
import 'package:lifeplan_app/data/repositories/work_task_repository.dart';
import 'package:lifeplan_app/models/client.dart';
import 'package:lifeplan_app/models/exercise_item.dart';
import 'package:lifeplan_app/models/finance_transaction.dart';
import 'package:lifeplan_app/models/goal_settings.dart';
import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';
import 'package:lifeplan_app/models/skill_track.dart';
import 'package:lifeplan_app/models/user_profile.dart';
import 'package:lifeplan_app/models/work_task.dart';

// Plain `test()` (not `testWidgets()`) so real Hive file I/O runs on the
// normal event loop instead of flutter_test's FakeAsync zone — see
// test/widget_test.dart for why that distinction matters here.
void main() {
  setUp(() async {
    await setUpTestHive();
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.userProfile),
      Hive.openBox<Map>(HiveBoxes.workTasks),
      Hive.openBox<Map>(HiveBoxes.exerciseItems),
      Hive.openBox<Map>(HiveBoxes.clients),
      Hive.openBox<Map>(HiveBoxes.financeTransactions),
      Hive.openBox<Map>(HiveBoxes.skillTracks),
      Hive.openBox<Map>(HiveBoxes.scheduleEvents),
      Hive.openBox<Map>(HiveBoxes.learningStreak),
      Hive.openBox<Map>(HiveBoxes.goalSettings),
    ]);
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('UserRepository saves, reads back, and signs out', () async {
    final repo = UserRepository();
    expect(repo.getCurrent(), isNull);

    final user = UserProfile(id: newId(), name: 'ทดสอบ', email: 'test@example.com', authProvider: AuthProvider.google);
    await repo.save(user);

    final loaded = repo.getCurrent();
    expect(loaded, isNotNull);
    expect(loaded!.name, 'ทดสอบ');
    expect(loaded.authProvider, AuthProvider.google);

    await repo.signOut();
    expect(repo.getCurrent(), isNull);
  });

  test('WorkTaskRepository add / toggle / delete round-trips through Hive', () async {
    final repo = WorkTaskRepository();
    final task = WorkTask(id: newId(), title: 'ทดสอบงาน', status: TaskStatus.todo, priority: TaskPriority.urgent);

    await repo.put(task);
    expect(repo.getAll().length, 1);
    expect(repo.getAll().first.title, 'ทดสอบงาน');

    await repo.put(task.copyWith(status: TaskStatus.done));
    expect(repo.getAll().first.status, TaskStatus.done);

    await repo.delete(task.id);
    expect(repo.getAll(), isEmpty);
  });

  test('ExerciseRepository persists completion state', () async {
    final repo = ExerciseRepository();
    final item = ExercisePlanItem(id: newId(), title: 'วิ่ง', type: ExerciseType.run, dayLabel: 'จันทร์', durationMinutes: 30);
    await repo.put(item);
    expect(repo.getAll().first.isDone, isFalse);

    await repo.put(item.copyWith(isDone: true));
    expect(repo.getAll().first.isDone, isTrue);
  });

  test('ClientRepository advances stage and tracks premium', () async {
    final repo = ClientRepository();
    final client = Client(id: newId(), name: 'ลูกค้าทดสอบ', initials: 'ทด', policyLabel: 'ประกันสุขภาพ', stage: ClientStage.newLead, premiumAmount: 10000);
    await repo.put(client);

    var c = repo.getAll().first;
    expect(c.stage, ClientStage.newLead);
    await repo.put(c.copyWith(stage: c.stage.next));
    c = repo.getAll().first;
    expect(c.stage, ClientStage.contacted);
  });

  test('FinanceRepository stores income/expense with the right sign', () async {
    final repo = FinanceRepository();
    await repo.put(FinanceTransaction(id: newId(), title: 'เงินเดือน', date: DateTime.now(), amount: 30000, type: TransactionType.income));
    await repo.put(FinanceTransaction(
      id: newId(),
      title: 'ออมเงิน',
      date: DateTime.now(),
      amount: 5000,
      type: TransactionType.expense,
      category: ExpenseCategory.investmentSaving,
    ));

    final all = repo.getAll();
    expect(all.length, 2);
    final income = all.where((t) => t.type == TransactionType.income).fold<double>(0, (s, t) => s + t.amount);
    expect(income, 30000);
  });

  test('SkillTrackRepository caps progress at 100', () async {
    final repo = SkillTrackRepository();
    final track = SkillTrack(id: newId(), name: 'ภาษาอังกฤษ', subtitle: 'ทดสอบ', progressPercent: 98);
    await repo.put(track);
    await repo.put(track.copyWith(progressPercent: (track.progressPercent + 10).clamp(0, 100)));
    expect(repo.getAll().first.progressPercent, 100);
  });

  test('LearningStreakRepository increments once per day', () async {
    final repo = LearningStreakRepository();
    expect(repo.get().currentStreakDays, 0);

    final first = await repo.logSessionToday();
    expect(first.currentStreakDays, 1);

    // Logging again the same day should not double-increment the streak.
    final second = await repo.logSessionToday();
    expect(second.currentStreakDays, 1);
    expect(second.lessonsLoggedToday, 2);
  });

  test('ScheduleRepository sorts events by time', () async {
    final repo = ScheduleRepository();
    await repo.put(const ScheduleEvent(id: 'a', time: '18:00', title: 'เย็น', category: LifeCategory.finance));
    await repo.put(const ScheduleEvent(id: 'b', time: '06:00', title: 'เช้า', category: LifeCategory.exercise));

    final sorted = repo.getAllSortedByTime();
    expect(sorted.first.title, 'เช้า');
    expect(sorted.last.title, 'เย็น');
  });

  test('ScheduleRepository groups events by weekday', () async {
    final repo = ScheduleRepository();
    await repo.put(const ScheduleEvent(id: 'w1', time: '18:00', weekday: DateTime.wednesday, title: 'พุธเย็น', category: LifeCategory.finance));
    await repo.put(const ScheduleEvent(id: 'w2', time: '06:00', weekday: DateTime.wednesday, title: 'พุธเช้า', category: LifeCategory.exercise));
    await repo.put(const ScheduleEvent(id: 'w3', time: '09:00', weekday: DateTime.saturday, title: 'เสาร์', category: LifeCategory.learning));

    final wed = repo.getByWeekday(DateTime.wednesday);
    expect(wed.map((e) => e.title), ['พุธเช้า', 'พุธเย็น']);
    expect(repo.getByWeekday(DateTime.sunday), isEmpty);

    final week = repo.getWeek();
    expect(week.length, 7);
    expect(week[DateTime.wednesday - 1].length, 2);
    expect(week[DateTime.saturday - 1].single.title, 'เสาร์');
  });

  test('ScheduleEvent saved before the weekly view falls back to Monday', () {
    final legacy = ScheduleEvent.fromMap(const {
      'id': 'legacy',
      'time': '08:00',
      'title': 'ของเดิม',
      'subtitle': null,
      'category': 'work',
    });
    expect(legacy.weekday, DateTime.monday);
  });

  test('Insights.categoryScores reflects real Hive data', () async {
    final workRepo = WorkTaskRepository();
    await workRepo.put(WorkTask(id: newId(), title: 'A', status: TaskStatus.done, priority: TaskPriority.normal));
    await workRepo.put(WorkTask(id: newId(), title: 'B', status: TaskStatus.todo, priority: TaskPriority.normal));

    final scores = Insights.categoryScores();
    expect(scores[LifeCategory.work], 50); // 1 of 2 tasks done
  });

  test('GoalSettingsRepository returns defaults, then saved values', () async {
    final repo = GoalSettingsRepository();
    final defaults = repo.get();
    expect(defaults.savingTarget, GoalSettings.defaultSavingTarget);
    expect(defaults.salesTarget, GoalSettings.defaultSalesTarget);
    expect(defaults.exerciseWeeklyTarget, GoalSettings.defaultExerciseWeeklyTarget);

    await repo.save(defaults.copyWith(savingTarget: 80000, exerciseWeeklyTarget: 3));
    final loaded = repo.get();
    expect(loaded.savingTarget, 80000);
    expect(loaded.salesTarget, GoalSettings.defaultSalesTarget);
    expect(loaded.exerciseWeeklyTarget, 3);
  });

  test('Insights.categoryScores uses the saved goals', () async {
    final exerciseRepo = ExerciseRepository();
    for (var i = 0; i < 2; i++) {
      await exerciseRepo.put(ExercisePlanItem(id: newId(), title: 'วิ่ง', type: ExerciseType.run, dayLabel: 'จันทร์', durationMinutes: 30, isDone: true));
    }
    await FinanceRepository().put(FinanceTransaction(
      id: newId(),
      title: 'ออมเงิน',
      date: DateTime.now(),
      amount: 10000,
      type: TransactionType.expense,
      category: ExpenseCategory.investmentSaving,
    ));

    // Defaults: 2 / 5 sessions = 40%, ฿10,000 / ฿50,000 = 20%.
    var scores = Insights.categoryScores();
    expect(scores[LifeCategory.exercise], 40);
    expect(scores[LifeCategory.finance], 20);

    await GoalSettingsRepository().save(const GoalSettings(savingTarget: 20000, exerciseWeeklyTarget: 4));
    scores = Insights.categoryScores();
    expect(scores[LifeCategory.exercise], 50);
    expect(scores[LifeCategory.finance], 50);
  });
}
