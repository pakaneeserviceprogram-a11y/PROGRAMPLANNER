import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/sleep_repository.dart';
import 'package:lifeplan_app/models/goal_settings.dart';
import 'package:lifeplan_app/models/sleep_entry.dart';
import 'package:lifeplan_app/screens/sleep_screen.dart';

void main() {
  setUp(() async {
    await setUpTestHive();
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.sleepEntries, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
      // การ์ด "เตือนให้เข้านอน" เขียนลงตารางเวลา จึงต้องเปิด box นี้ด้วย
      Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
    ]);
  });

  tearDown(() async {
    await Hive.close();
    await tearDownTestHive();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const SleepScreen(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('ยังไม่มีบันทึก — ชวนให้บันทึกคืนแรก', (tester) async {
    await pumpScreen(tester);

    expect(find.text('คุณภาพการนอน'), findsOneWidget);
    expect(find.text('ยังไม่ได้บันทึกการนอนเมื่อคืน'), findsOneWidget);
    expect(find.text('ยังไม่มีบันทึกการนอนในสัปดาห์นี้'), findsOneWidget);
  });

  testWidgets('มีบันทึกเมื่อคืนแล้ว แสดงเวลานอนและคุณภาพ', (tester) async {
    await SleepRepository().put(SleepEntry(
      date: DateTime.now(),
      bedTime: '23:00',
      wakeTime: '06:30',
      quality: SleepQuality.good,
      awakenings: 1,
    ));

    await pumpScreen(tester);

    expect(find.text('เมื่อคืน'), findsOneWidget);
    // โผล่ทั้งการ์ดหัวเรื่องและในรายการประวัติ
    expect(find.text('7 ชม. 30 นาที'), findsWidgets);
    expect(find.text('23:00'), findsWidgets);
    expect(find.text('ดี'), findsWidgets);
  });

  testWidgets('บันทึกการนอนผ่านฟอร์มแล้วเก็บลง Hive จริง', (tester) async {
    await pumpScreen(tester);

    await tester.scrollUntilVisible(find.text('บันทึกการนอน'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('บันทึกการนอน').last);
    await tester.pumpAndSettle();

    // ค่าเริ่มต้นในฟอร์มคือ 23:00 → 07:00 = 8 ชั่วโมง
    expect(find.text('ได้นอน 8 ชม.'), findsOneWidget);

    final submit = find.text('บันทึก').last;
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final saved = SleepRepository().getLastNight();
    expect(saved, isNotNull);
    expect(saved!.bedTime, '23:00');
    expect(saved.wakeTime, '07:00');
    expect(saved.durationMinutes, 480);
  });

  testWidgets('แตะรายการเดิมเปิดฟอร์มแก้ไข ไม่สร้างรายการใหม่', (tester) async {
    final repo = SleepRepository();
    await repo.put(SleepEntry(date: DateTime.now(), bedTime: '01:00', wakeTime: '06:00'));

    await pumpScreen(tester);
    await tester.scrollUntilVisible(find.byIcon(Icons.chevron_right_rounded), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขการนอน'), findsOneWidget);
    expect(find.text('ลบบันทึกคืนนี้'), findsOneWidget);

    final submit = find.text('บันทึก').last;
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repo.getAll(), hasLength(1));
  });

  group('คำแนะนำ', () {
    const goals = GoalSettings();

    SleepEntry night(int daysAgo, {String bed = '23:00', String wake = '07:00', int awakenings = 0}) =>
        SleepEntry(
          date: DateTime(2026, 9, 16).subtract(Duration(days: daysAgo)),
          bedTime: bed,
          wakeTime: wake,
          awakenings: awakenings,
        );

    test('ยังไม่มีข้อมูล = ไม่แนะนำอะไร', () {
      expect(SleepScreen.tipsFor(SleepStats.of(const []), goals), isEmpty);
    });

    test('นอนน้อยกว่าเป้าเยอะ จะเตือนเรื่องเวลานอน', () {
      final stats = SleepStats.of([night(0, wake: '05:00'), night(1, wake: '05:00')]);
      expect(SleepScreen.tipsFor(stats, goals).first, contains('น้อยกว่าเป้า'));
    });

    test('ตื่นกลางดึกบ่อยจะมีคำแนะนำเรื่องนี้', () {
      final stats = SleepStats.of([night(0, awakenings: 2), night(1, awakenings: 2)]);
      expect(
        SleepScreen.tipsFor(stats, goals).any((t) => t.contains('ตื่นกลางดึก')),
        isTrue,
      );
    });

    test('เวลาเข้านอนเหวี่ยงจะเตือนเรื่องความสม่ำเสมอ', () {
      final stats = SleepStats.of([
        night(0, bed: '21:00'),
        night(1, bed: '01:00'),
        night(2, bed: '23:00'),
      ]);
      expect(
        SleepScreen.tipsFor(stats, goals).any((t) => t.contains('สม่ำเสมอ')),
        isTrue,
      );
    });
  });
}
