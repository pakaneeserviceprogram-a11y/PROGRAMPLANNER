import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/sleep_repository.dart';
import 'package:lifeplan_app/data/sleep_history.dart';
import 'package:lifeplan_app/models/sleep_entry.dart';
import 'package:lifeplan_app/screens/sleep_screen.dart';
import 'package:lifeplan_app/widgets/app_card.dart';

/// กราฟการนอนย้อนหลัง 30 คืน — คืนที่ยังไม่ได้บันทึกต้องมีช่องของตัวเอง
/// ไม่งั้นกราฟจะบีบวันที่ขาดหายจนดูเหมือนนอนต่อเนื่องทุกคืน
void main() {
  final today = DateTime(2026, 9, 18);
  DateTime nightsAgo(int n) => DateTime(today.year, today.month, today.day - n);

  Future<void> logNight(int daysAgo, {String bed = '23:00', String wake = '07:00'}) =>
      SleepRepository().put(SleepEntry(date: nightsAgo(daysAgo), bedTime: bed, wakeTime: wake));

  setUp(() async {
    await setUpTestHive();
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.sleepEntries, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
      Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
      // การ์ด "การนอนกับสิ่งที่กิน" อ่านมื้ออาหารของวันนั้น
      Hive.openBox<Map>(HiveBoxes.mealEntries, bytes: Uint8List(0)),
    ]);
  });

  tearDown(() async {
    await Hive.close();
    await tearDownTestHive();
  });

  test('มีครบ 30 ช่อง เรียงเก่า → ใหม่ คืนที่ไม่ได้บันทึกยังมีช่องว่าง', () async {
    await logNight(0);
    await logNight(10);
    final history = SleepHistory.of(SleepRepository(), days: 30, until: today);

    expect(history.nights, hasLength(30));
    expect(history.nights.first.date, nightsAgo(29));
    expect(history.nights.last.date, today);
    expect(history.nights.last.isLogged, isTrue);
    expect(history.nights[28].isLogged, isFalse); // เมื่อวานยังไม่ได้บันทึก
    expect(history.loggedCount, 2);
  });

  test('สถิติและคืนที่ถึงเป้านับเฉพาะคืนที่บันทึกไว้', () async {
    await logNight(0, bed: '23:00', wake: '07:00'); // 8 ชม.
    await logNight(1, bed: '00:30', wake: '06:00'); // 5 ชม. 30 นาที
    final history = SleepHistory.of(SleepRepository(), days: 30, until: today);

    expect(history.stats.nightCount, 2);
    expect(history.stats.averageMinutes, (480 + 330) / 2);
    expect(history.nightsMeetingTarget(480), 1);
    expect(history.maxMinutes, 480);
  });

  test('ค่าเฉลี่ยรายสัปดาห์: สัปดาห์ที่ไม่มีบันทึกเลยได้ null', () async {
    // สัปดาห์ล่าสุด (0–6 คืนก่อน) มีสองคืน ส่วนสัปดาห์อื่นว่าง
    await logNight(0, bed: '23:00', wake: '07:00'); // 8 ชม.
    await logNight(3, bed: '23:00', wake: '06:00'); // 7 ชม.
    final weekly = SleepHistory.of(SleepRepository(), days: 30, until: today).weeklyAverages();

    expect(weekly.last, (480 + 420) / 2);
    expect(weekly.where((w) => w == null), isNotEmpty);
    expect(weekly.length, greaterThanOrEqualTo(4));
  });

  testWidgets('หน้าจอแสดงการ์ดย้อนหลัง 30 คืน พร้อมค่าเฉลี่ยและคืนที่ถึงเป้า', (tester) async {
    final now = DateTime.now();
    await SleepRepository().put(SleepEntry(date: now, bedTime: '23:00', wakeTime: '07:00'));
    await SleepRepository().put(SleepEntry(
      date: DateTime(now.year, now.month, now.day - 1),
      bedTime: '01:00',
      wakeTime: '06:00',
    ));

    await tester.pumpWidget(const MaterialApp(home: SleepScreen()));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('ย้อนหลัง 30 คืน'), 250);
    await tester.pumpAndSettle();

    expect(find.text('บันทึกแล้ว 2 คืน'), findsOneWidget);

    // การ์ดค่าเฉลี่ย 7 คืนด้านบนก็มีตัวเลขชุดเดียวกัน — ดูเฉพาะในการ์ด 30 คืน
    final card = find.ancestor(of: find.text('ย้อนหลัง 30 คืน'), matching: find.byType(AppCard)).first;
    // 8 ชม. กับ 5 ชม. → เฉลี่ย 6 ชม. 30 นาที และถึงเป้า (8 ชม.) 1 คืน
    expect(find.descendant(of: card, matching: find.text('6 ชม. 30 นาที')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('1 / 2')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('คืนที่ถึงเป้า')), findsOneWidget);
  });

  testWidgets('ยังไม่มีบันทึกต้องชวนให้เริ่มบันทึกแทนกราฟเปล่า', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SleepScreen()));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('ย้อนหลัง 30 คืน'), 250);
    await tester.pumpAndSettle();
    expect(find.textContaining('ยังไม่มีบันทึกย้อนหลัง'), findsOneWidget);
  });
}
