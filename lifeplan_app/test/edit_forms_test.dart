import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/client_repository.dart';
import 'package:lifeplan_app/data/repositories/exercise_repository.dart';
import 'package:lifeplan_app/data/repositories/finance_repository.dart';
import 'package:lifeplan_app/data/repositories/skill_track_repository.dart';
import 'package:lifeplan_app/data/repositories/work_task_repository.dart';
import 'package:lifeplan_app/models/client.dart';
import 'package:lifeplan_app/models/exercise_item.dart';
import 'package:lifeplan_app/models/finance_transaction.dart';
import 'package:lifeplan_app/models/skill_track.dart';
import 'package:lifeplan_app/models/work_task.dart';
import 'package:lifeplan_app/screens/crm_screen.dart';
import 'package:lifeplan_app/screens/exercise_screen.dart';
import 'package:lifeplan_app/screens/finance_screen.dart';
import 'package:lifeplan_app/screens/learning_screen.dart';
import 'package:lifeplan_app/screens/work_screen.dart';

/// ฟอร์มแก้ไข/ลบของหน้างานประจำ ออกกำลังกาย การเงิน เรียนรู้ และลูกค้า
///
/// box แบบ in-memory (bytes:) เหมือน schedule_screen_test — การเขียนจบได้ภายใน FakeAsync
void main() {
  setUp(() async {
    await setUpTestHive();
    await Future.wait([
      for (final name in [
        HiveBoxes.workTasks,
        HiveBoxes.exerciseItems,
        HiveBoxes.financeTransactions,
        HiveBoxes.skillTracks,
        HiveBoxes.learningStreak,
        HiveBoxes.clients,
        HiveBoxes.weeklyReports,
        HiveBoxes.goalSettings,
        HiveBoxes.userProfile,
      ])
        Hive.openBox<Map>(name, bytes: Uint8List(0)),
    ]);
  });

  tearDown(() async {
    await Hive.close();
    await tearDownTestHive();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
  }

  /// ฟอร์มยาวเกินจอทดสอบ — เลื่อนสองรอบเหมือน schedule_screen_test
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> replaceField(WidgetTester tester, String currentText, String newText) async {
    await tester.enterText(find.widgetWithText(TextField, currentText), newText);
    await tester.pump();
  }

  Future<void> pickDropdown(WidgetTester tester, String current, String next) async {
    await tapVisible(tester, find.text(current).last);
    await tester.tap(find.text(next).last);
    await tester.pumpAndSettle();
  }

  group('งานประจำ', () {
    setUp(() async {
      await WorkTaskRepository().put(const WorkTask(id: 't1', title: 'ส่งรายงาน', status: TaskStatus.todo, priority: TaskPriority.normal, dueLabel: '17:00'));
    });

    testWidgets('แก้ชื่อและเปลี่ยนสถานะเป็นกำลังทำ พร้อมความคืบหน้า', (tester) async {
      await pump(tester, const WorkScreen());
      await tapVisible(tester, find.byIcon(Icons.edit_outlined));
      expect(find.text('แก้ไขงาน'), findsOneWidget);

      await replaceField(tester, 'ส่งรายงาน', 'ส่งรายงานประจำเดือน');
      await pickDropdown(tester, 'ต้องทำ', 'กำลังทำ');
      await tester.enterText(find.widgetWithText(TextField, 'เช่น 60'), '40');
      await tapVisible(tester, find.text('บันทึก'));

      final task = WorkTaskRepository().getAll().single;
      expect(task.id, 't1');
      expect(task.title, 'ส่งรายงานประจำเดือน');
      expect(task.status, TaskStatus.inProgress);
      expect(task.progressPercent, 40);
      expect(task.dueLabel, '17:00');
    });

    testWidgets('ลบจากฟอร์มต้องยืนยันก่อน', (tester) async {
      await pump(tester, const WorkScreen());
      await tapVisible(tester, find.byIcon(Icons.edit_outlined));
      await tapVisible(tester, find.text('ลบงานนี้'));
      expect(find.text('ลบงานนี้?'), findsOneWidget);

      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();
      expect(WorkTaskRepository().getAll(), hasLength(1));

      await tapVisible(tester, find.text('ลบงานนี้'));
      await tester.tap(find.widgetWithText(TextButton, 'ลบ'));
      await tester.pumpAndSettle();
      expect(WorkTaskRepository().getAll(), isEmpty);
      expect(find.text('ลบ “ส่งรายงาน” แล้ว'), findsOneWidget);
    });
  });

  group('ออกกำลังกาย', () {
    testWidgets('แก้ไขแล้วชื่อไม่ซ้อนคำนำหน้าวัน และยังคงสถานะเสร็จไว้', (tester) async {
      await ExerciseRepository().put(const ExercisePlanItem(
        id: 'e1',
        title: 'จันทร์ • วิ่งตอนเช้า',
        type: ExerciseType.run,
        dayLabel: 'จันทร์',
        durationMinutes: 30,
        isDone: true,
      ));
      await pump(tester, const ExerciseScreen());
      await tapVisible(tester, find.byIcon(Icons.edit_outlined));

      // ช่องชื่อต้องไม่มี "จันทร์ • " ติดมา
      expect(find.widgetWithText(TextField, 'วิ่งตอนเช้า'), findsOneWidget);
      await replaceField(tester, 'วิ่งตอนเช้า', 'วิ่งริมแม่น้ำ');
      await pickDropdown(tester, 'จันทร์', 'พุธ');
      await replaceField(tester, '30', '45');
      await tapVisible(tester, find.text('บันทึก'));

      final item = ExerciseRepository().getAll().single;
      expect(item.title, 'พุธ • วิ่งริมแม่น้ำ');
      expect(item.dayLabel, 'พุธ');
      expect(item.durationMinutes, 45);
      expect(item.isDone, isTrue);
    });

    test('plainTitle ตัดเฉพาะคำนำหน้าวันของรายการนั้น', () {
      const item = ExercisePlanItem(id: 'x', title: 'อังคาร • ว่ายน้ำ', type: ExerciseType.swim, dayLabel: 'อังคาร', durationMinutes: 20);
      const legacy = ExercisePlanItem(id: 'y', title: 'โยคะ', type: ExerciseType.stretch, dayLabel: 'อังคาร', durationMinutes: 20);
      expect(ExerciseScreen.plainTitle(item), 'ว่ายน้ำ');
      expect(ExerciseScreen.plainTitle(legacy), 'โยคะ');
    });
  });

  group('การเงิน', () {
    testWidgets('แตะรายการเพื่อแก้จำนวนเงิน วันที่เดิมไม่เปลี่ยน', (tester) async {
      final date = DateTime.now().subtract(const Duration(days: 3));
      await FinanceRepository().put(FinanceTransaction(
        id: 'f1',
        title: 'ข้าวกลางวัน',
        date: date,
        amount: 80,
        type: TransactionType.expense,
        category: ExpenseCategory.food,
      ));
      await pump(tester, const FinanceScreen());
      await tapVisible(tester, find.text('ข้าวกลางวัน'));
      expect(find.text('แก้ไขรายการ'), findsOneWidget);

      await replaceField(tester, '80', '1,250');
      await tapVisible(tester, find.text('บันทึก'));

      final tx = FinanceRepository().getAll().single;
      expect(tx.amount, 1250);
      expect(tx.date, date);
      expect(tx.category, ExpenseCategory.food);
    });

    testWidgets('ลบรายการจากฟอร์มแก้ไข', (tester) async {
      await FinanceRepository().put(FinanceTransaction(id: 'f1', title: 'เงินเดือน', date: DateTime.now(), amount: 30000, type: TransactionType.income));
      await pump(tester, const FinanceScreen());
      await tapVisible(tester, find.text('เงินเดือน'));
      await tapVisible(tester, find.text('ลบรายการนี้'));
      await tester.tap(find.widgetWithText(TextButton, 'ลบ'));
      await tester.pumpAndSettle();

      expect(FinanceRepository().getAll(), isEmpty);
    });
  });

  group('เรียนรู้', () {
    testWidgets('แตะการ์ดเพื่อแก้ชื่อและความคืบหน้า (จำกัดไม่เกิน 100)', (tester) async {
      await SkillTrackRepository().put(const SkillTrack(id: 's1', name: 'ภาษาญี่ปุ่น', subtitle: 'N5', progressPercent: 20, isPrimary: true));
      await pump(tester, const LearningScreen());
      await tapVisible(tester, find.text('ภาษาญี่ปุ่น'));
      expect(find.text('แก้ไขเส้นทางการเรียนรู้'), findsOneWidget);

      await replaceField(tester, 'N5', 'N4');
      await replaceField(tester, '20', '150');
      await tapVisible(tester, find.text('บันทึก'));

      final track = SkillTrackRepository().getAll().single;
      expect(track.subtitle, 'N4');
      expect(track.progressPercent, 100);
      expect(track.isPrimary, isTrue);
    });

    testWidgets('ปุ่ม "เรียนต่อ" ยังทำงานแยกจากการแตะการ์ด', (tester) async {
      await SkillTrackRepository().put(const SkillTrack(id: 's1', name: 'ภาษาญี่ปุ่น', subtitle: 'N5', progressPercent: 20));
      await pump(tester, const LearningScreen());
      await tapVisible(tester, find.text('เรียนต่อ'));

      expect(find.text('แก้ไขเส้นทางการเรียนรู้'), findsNothing);
      expect(SkillTrackRepository().getAll().single.progressPercent, 24);
    });
  });

  group('ลูกค้า', () {
    setUp(() async {
      await ClientRepository().put(const Client(
        id: 'c1',
        name: 'คุณสมชาย ใจดี',
        initials: 'สม',
        policyLabel: 'ประกันสุขภาพ • นัดพบวันนี้',
        stage: ClientStage.followUp,
        premiumAmount: 42000,
      ));
    });

    testWidgets('ย้อนสถานะที่แตะเกินกลับได้จากฟอร์มแก้ไข', (tester) async {
      await pump(tester, const CrmScreen());
      // รายชื่อลูกค้าอยู่ใต้รายงานประจำสัปดาห์ ListView ยังไม่สร้างจนกว่าจะเลื่อนลงไป
      await tester.scrollUntilVisible(find.byIcon(Icons.edit_outlined), 250);
      await tapVisible(tester, find.byIcon(Icons.edit_outlined));
      expect(find.text('แก้ไขข้อมูลลูกค้า'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'ประกันสุขภาพ • นัดพบวันนี้'), findsOneWidget);

      await pickDropdown(tester, 'ติดตามวันนี้', 'รอตอบกลับ');
      await replaceField(tester, '42000', '50000');
      await tapVisible(tester, find.text('บันทึก'));

      final client = ClientRepository().getAll().single;
      expect(client.stage, ClientStage.proposalSent);
      expect(client.premiumAmount, 50000);
      expect(client.policyLabel, 'ประกันสุขภาพ • นัดพบวันนี้');
    });

    testWidgets('ลบลูกค้าจากฟอร์มแก้ไข', (tester) async {
      await pump(tester, const CrmScreen());
      // รายชื่อลูกค้าอยู่ใต้รายงานประจำสัปดาห์ ListView ยังไม่สร้างจนกว่าจะเลื่อนลงไป
      await tester.scrollUntilVisible(find.byIcon(Icons.edit_outlined), 250);
      await tapVisible(tester, find.byIcon(Icons.edit_outlined));
      await tapVisible(tester, find.text('ลบลูกค้ารายนี้'));
      await tester.tap(find.widgetWithText(TextButton, 'ลบ'));
      await tester.pumpAndSettle();

      expect(ClientRepository().getAll(), isEmpty);
    });
  });
}
