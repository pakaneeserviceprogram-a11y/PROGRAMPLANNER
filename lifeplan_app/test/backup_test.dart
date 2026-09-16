import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/backup.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/app_settings_repository.dart';
import 'package:lifeplan_app/data/repositories/client_repository.dart';
import 'package:lifeplan_app/data/repositories/goal_settings_repository.dart';
import 'package:lifeplan_app/data/repositories/schedule_repository.dart';
import 'package:lifeplan_app/data/repositories/user_repository.dart';
import 'package:lifeplan_app/data/repositories/work_task_repository.dart';
import 'package:lifeplan_app/data/seed_data.dart';
import 'package:lifeplan_app/models/client.dart';
import 'package:lifeplan_app/models/goal_settings.dart';
import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';
import 'package:lifeplan_app/models/user_profile.dart';
import 'package:lifeplan_app/models/work_task.dart';

void main() {
  setUp(() async {
    await setUpTestHive();
    // เปิด box เองแทน HiveBoxes.init() เพราะ initFlutter() ต้องใช้ path_provider
    // ซึ่งไม่มี plugin จริงในเทสต์
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.userProfile),
      Hive.openBox<Map>(HiveBoxes.workTasks),
      Hive.openBox<Map>(HiveBoxes.exerciseItems),
      Hive.openBox<Map>(HiveBoxes.mealEntries),
      Hive.openBox<Map>(HiveBoxes.waterLogs),
      Hive.openBox<Map>(HiveBoxes.sleepEntries),
      Hive.openBox<Map>(HiveBoxes.clients),
      Hive.openBox<Map>(HiveBoxes.weeklyReports),
      Hive.openBox<Map>(HiveBoxes.financeTransactions),
      Hive.openBox<Map>(HiveBoxes.skillTracks),
      Hive.openBox<Map>(HiveBoxes.scheduleEvents),
      Hive.openBox<Map>(HiveBoxes.learningStreak),
      Hive.openBox<Map>(HiveBoxes.goalSettings),
      Hive.openBox<Map>(HiveBoxes.appSettings),
    ]);
  });

  tearDown(tearDownTestHive);

  Future<void> seed() async {
    await WorkTaskRepository().put(WorkTask(id: 't1', title: 'งานทดสอบ', status: TaskStatus.todo, priority: TaskPriority.urgent));
    await ClientRepository().put(Client(id: 'c1', name: 'คุณสมชาย', initials: 'สช', policyLabel: 'ประกันสุขภาพ', stage: ClientStage.followUp));
    await ScheduleRepository().put(const ScheduleEvent(
        id: 's1', time: '09:00', weekday: DateTime.friday, title: 'ประชุม', category: LifeCategory.work));
    await GoalSettingsRepository().save(const GoalSettings(savingTarget: 12345, salesTarget: 7, exerciseWeeklyTarget: 4));
  }

  test('ล้างประวัติ ลบเฉพาะข้อมูลที่บันทึกไว้ แต่บัญชีและเป้าหมายยังอยู่', () async {
    await seed();
    await UserRepository().save(const UserProfile(
        id: 'u1', name: 'ทดสอบ', email: 'test@example.com', authProvider: AuthProvider.email));

    final removed = await BackupService.clearRecords();

    expect(removed, 3); // งาน 1 + ลูกค้า 1 + ตารางเวลา 1
    expect(WorkTaskRepository().getAll(), isEmpty);
    expect(ClientRepository().getAll(), isEmpty);
    expect(ScheduleRepository().getAll(), isEmpty);

    // สิ่งที่ต้องรอด: บัญชีผู้ใช้ + เป้าหมาย
    expect(UserRepository().getCurrent()?.name, 'ทดสอบ');
    expect(GoalSettingsRepository().get().savingTarget, 12345);
  });

  test('ล้างทุกอย่าง ลบบัญชีและเป้าหมายด้วย', () async {
    await seed();
    await UserRepository().save(const UserProfile(
        id: 'u1', name: 'ทดสอบ', email: 'test@example.com', authProvider: AuthProvider.email));

    await BackupService.clearEverything();

    expect(UserRepository().getCurrent(), isNull);
    expect(WorkTaskRepository().getAll(), isEmpty);
    // เป้าหมายกลับไปเป็นค่าเริ่มต้น ไม่ใช่ 12345 ที่เคยตั้งไว้
    expect(GoalSettingsRepository().get().savingTarget, isNot(12345));
  });

  test('ล้างข้อมูลแล้ว ข้อมูลตัวอย่างต้องไม่กลับมาตอนเปิดแอปครั้งหน้า', () async {
    await BackupService.clearRecords();
    expect(AppSettingsRepository().get().sampleDataDisabled, isTrue);

    // จำลองการเปิดแอปรอบถัดไป
    await SeedData.seedIfEmpty();

    expect(ClientRepository().getAll(), isEmpty);
    expect(WorkTaskRepository().getAll(), isEmpty);
    expect(ScheduleRepository().getAll(), isEmpty);
  });

  test('ล้างทุกอย่างแล้ว ธงกันข้อมูลตัวอย่างต้องยังอยู่ (ไม่ถูกล้างไปด้วย)', () async {
    await BackupService.clearEverything();
    expect(AppSettingsRepository().get().sampleDataDisabled, isTrue);

    await SeedData.seedIfEmpty();
    expect(ClientRepository().getAll(), isEmpty);
  });

  test('ส่งออกแล้วกู้คืนได้ข้อมูลเดิมครบ', () async {
    await seed();
    final json = BackupService.exportToJson();

    // ล้างข้อมูลเหมือนลงแอปใหม่ในเครื่องใหม่
    await WorkTaskRepository().delete('t1');
    await ClientRepository().delete('c1');
    await ScheduleRepository().delete('s1');
    expect(WorkTaskRepository().getAll(), isEmpty);

    await BackupService.importFromJson(json);

    expect(WorkTaskRepository().getAll().single.title, 'งานทดสอบ');
    expect(ClientRepository().getAll().single.name, 'คุณสมชาย');
    final event = ScheduleRepository().getAll().single;
    expect(event.title, 'ประชุม');
    expect(event.weekday, DateTime.friday);
    expect(GoalSettingsRepository().get().savingTarget, 12345);
  });

  test('กู้คืนแทนที่ข้อมูลเดิมทั้งหมด ไม่ใช่เขียนเพิ่ม', () async {
    await seed();
    final json = BackupService.exportToJson();

    await WorkTaskRepository().put(WorkTask(id: 't2', title: 'งานที่เพิ่มทีหลัง', status: TaskStatus.todo, priority: TaskPriority.normal));
    expect(WorkTaskRepository().getAll().length, 2);

    await BackupService.importFromJson(json);
    expect(WorkTaskRepository().getAll().map((t) => t.id), ['t1']);
  });

  test('summarize บอกจำนวนรายการในไฟล์', () async {
    await seed();
    final summary = BackupService.summarize(BackupService.exportToJson());
    expect(summary[HiveBoxes.workTasks], 1);
    expect(summary[HiveBoxes.scheduleEvents], 1);
  });

  test('ไฟล์ที่ไม่ใช่ของ LifePlan ถูกปฏิเสธและข้อมูลเดิมไม่ถูกแตะ', () async {
    await seed();

    expect(() => BackupService.importFromJson('ไม่ใช่ json'), throwsA(isA<BackupException>()));
    expect(() => BackupService.importFromJson('{"app":"other","formatVersion":1,"boxes":{}}'),
        throwsA(isA<BackupException>()));
    expect(() => BackupService.importFromJson('{"app":"lifeplan","formatVersion":99,"boxes":{}}'),
        throwsA(isA<BackupException>()));

    expect(WorkTaskRepository().getAll().single.title, 'งานทดสอบ');
  });

  test('รายการเสียหายใน box ไม่ทำให้ข้อมูลเดิมหายครึ่ง ๆ กลาง ๆ', () async {
    await seed();
    const broken = '{"app":"lifeplan","formatVersion":1,"boxes":{"work_tasks":{"x":"ไม่ใช่ object"}}}';

    expect(() => BackupService.importFromJson(broken), throwsA(isA<BackupException>()));
    expect(WorkTaskRepository().getAll().single.title, 'งานทดสอบ');
    expect(ClientRepository().getAll().single.name, 'คุณสมชาย');
  });
}
