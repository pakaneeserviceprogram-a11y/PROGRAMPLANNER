import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/insights.dart';
import 'package:lifeplan_app/data/repositories/sleep_repository.dart';
import 'package:lifeplan_app/models/goal_settings.dart';
import 'package:lifeplan_app/models/sleep_entry.dart';

SleepEntry night(
  DateTime date, {
  String bed = '23:00',
  String wake = '07:00',
  SleepQuality quality = SleepQuality.good,
  int awakenings = 0,
  List<SleepFactor> factors = const [],
}) =>
    SleepEntry(
      date: date,
      bedTime: bed,
      wakeTime: wake,
      quality: quality,
      awakenings: awakenings,
      factors: factors,
    );

void main() {
  group('SleepEntry', () {
    test('ระยะเวลานอนข้ามเที่ยงคืนถูกต้อง', () {
      expect(night(DateTime(2026, 9, 16), bed: '23:00', wake: '06:30').durationMinutes, 450);
      expect(night(DateTime(2026, 9, 16), bed: '00:40', wake: '06:30').durationMinutes, 350);
      expect(night(DateTime(2026, 9, 16), bed: '22:00', wake: '22:00').durationMinutes, 0);
    });

    test('เวลาที่อ่านไม่ออกให้ระยะเวลาเป็น 0 แทนที่จะพัง', () {
      expect(night(DateTime(2026, 9, 16), bed: 'ไม่ใช่เวลา').durationMinutes, 0);
      expect(SleepEntry.minutesOf('25:00'), isNull);
      expect(SleepEntry.minutesOf('7:5'), 425);
    });

    test('เข้านอนตอนค่ำ = คืนของวันก่อนหน้าวันที่ตื่น', () {
      expect(night(DateTime(2026, 9, 16), bed: '23:10').nightDate, DateTime(2026, 9, 15));
    });

    test('เข้านอนหลังเที่ยงคืน = ยังเป็นคืนของวันที่ตื่นเอง', () {
      expect(night(DateTime(2026, 9, 16), bed: '01:10', wake: '07:30').nightDate, DateTime(2026, 9, 16));
    });

    test('บันทึกแล้วอ่านกลับมาได้ครบทุกฟิลด์', () {
      final original = night(
        DateTime(2026, 9, 16),
        bed: '23:45',
        wake: '06:15',
        quality: SleepQuality.fair,
        awakenings: 2,
        factors: const [SleepFactor.caffeine, SleepFactor.screen],
      );
      final restored = SleepEntry.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.bedTime, '23:45');
      expect(restored.wakeTime, '06:15');
      expect(restored.quality, SleepQuality.fair);
      expect(restored.awakenings, 2);
      expect(restored.factors, [SleepFactor.caffeine, SleepFactor.screen]);
      expect(restored.durationMinutes, original.durationMinutes);
    });
  });

  group('SleepStats', () {
    test('เฉลี่ยเวลานอน คุณภาพ และการตื่นกลางดึกจากหลายคืน', () {
      final stats = SleepStats.of([
        night(DateTime(2026, 9, 14), bed: '23:00', wake: '07:00', quality: SleepQuality.excellent),
        night(DateTime(2026, 9, 15), bed: '23:00', wake: '05:00', quality: SleepQuality.poor, awakenings: 2),
      ]);

      expect(stats.nightCount, 2);
      expect(stats.averageMinutes, 420); // (480 + 360) / 2
      expect(stats.averageQuality, closeTo(0.625, 0.001)); // (1.0 + 0.25) / 2
      expect(stats.averageAwakenings, 1);
    });

    test('เข้านอนเวลาเดิมทุกคืน = สม่ำเสมอ 100%', () {
      final stats = SleepStats.of([
        night(DateTime(2026, 9, 14), bed: '23:00'),
        night(DateTime(2026, 9, 15), bed: '23:00'),
        night(DateTime(2026, 9, 16), bed: '23:00'),
      ]);
      expect(stats.bedtimeConsistency, 1);
    });

    test('เข้านอน 23:00 สลับกับตีหนึ่ง ต้องนับว่าเหวี่ยง ไม่ใช่ห่างกัน 22 ชั่วโมง', () {
      final stats = SleepStats.of([
        night(DateTime(2026, 9, 15), bed: '23:00'),
        night(DateTime(2026, 9, 16), bed: '01:00'),
      ]);
      // เหวี่ยงเฉลี่ย 60 นาที → 1 - 60/90 ≈ 0.33 (ถ้าคิดผิดจะกลายเป็น 0 ทันที)
      expect(stats.bedtimeConsistency, closeTo(1 / 3, 0.01));
    });

    test('ปัจจัยรบกวนเรียงจากที่เจอบ่อยสุด', () {
      final stats = SleepStats.of([
        night(DateTime(2026, 9, 14), factors: const [SleepFactor.screen, SleepFactor.stress]),
        night(DateTime(2026, 9, 15), factors: const [SleepFactor.screen]),
        night(DateTime(2026, 9, 16), factors: const [SleepFactor.screen, SleepFactor.noise]),
      ]);
      expect(stats.commonFactors.first, SleepFactor.screen);
      expect(stats.commonFactors, hasLength(3));
    });

    test('ยังไม่มีคืนไหนเลย = ว่าง', () {
      expect(SleepStats.of(const []).isEmpty, isTrue);
    });
  });

  group('Insights.scoreOfNight', () {
    const target = GoalSettings.defaultSleepTargetMinutes; // 480 นาที

    test('นอนครบเป้า คุณภาพดีมาก ไม่ตื่นกลางดึก = 100', () {
      final entry = night(DateTime(2026, 9, 16), bed: '23:00', wake: '07:00', quality: SleepQuality.excellent);
      expect(Insights.scoreOfNight(entry, target), 100);
    });

    test('นอนน้อย คุณภาพแย่ ตื่นหลายครั้ง ได้คะแนนต่ำ', () {
      final entry = night(
        DateTime(2026, 9, 16),
        bed: '01:00',
        wake: '05:00',
        quality: SleepQuality.poor,
        awakenings: 3,
      );
      // (240/480 + 0.25 + 0.55) / 3 ≈ 43%
      expect(Insights.scoreOfNight(entry, target), 43);
    });

    test('ตื่นกลางดึกถี่มากก็ยังไม่หักเกินพื้น 40%', () {
      final many = night(DateTime(2026, 9, 16), quality: SleepQuality.excellent, awakenings: 10);
      final more = night(DateTime(2026, 9, 16), quality: SleepQuality.excellent, awakenings: 20);
      expect(Insights.scoreOfNight(many, target), Insights.scoreOfNight(more, target));
    });

    test('นอนเกินเป้าไม่ได้คะแนนเกิน 100', () {
      final entry = night(DateTime(2026, 9, 16), bed: '21:00', wake: '09:00', quality: SleepQuality.excellent);
      expect(Insights.scoreOfNight(entry, target), 100);
    });
  });

  group('SleepRepository', () {
    setUp(() async {
      await setUpTestHive();
      await Hive.openBox<Map>(HiveBoxes.sleepEntries, bytes: Uint8List(0));
      await Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0));
    });

    tearDown(() async {
      // memory box ลบจากดิสก์ไม่ได้ ต้องปิดก่อนแล้วค่อยเก็บกวาด
      await Hive.close();
      await tearDownTestHive();
    });

    test('บันทึกคืนเดิมซ้ำทับรายการเดิม ไม่เพิ่มรายการใหม่', () async {
      final repo = SleepRepository();
      final day = DateTime(2026, 9, 16);

      await repo.put(night(day, bed: '23:00', wake: '06:00'));
      await repo.put(night(day, bed: '22:30', wake: '06:30'));

      expect(repo.getAll(), hasLength(1));
      expect(repo.getForDay(day)!.bedTime, '22:30');
    });

    test('getRecent คืนเฉพาะคืนที่บันทึกไว้จริง เรียงจากเก่าไปใหม่', () async {
      final repo = SleepRepository();
      final until = DateTime(2026, 9, 16);

      await repo.put(night(until.subtract(const Duration(days: 4))));
      await repo.put(night(until.subtract(const Duration(days: 1))));
      await repo.put(night(until));
      // นอกหน้าต่าง 7 วัน — ต้องไม่ติดมาด้วย
      await repo.put(night(until.subtract(const Duration(days: 20))));

      final recent = repo.getRecent(days: 7, until: until);
      expect(recent, hasLength(3));
      expect(recent.first.date.isBefore(recent.last.date), isTrue);
      expect(recent.last.date, DateTime(2026, 9, 16));
    });

    test('สถิติ 7 คืนล่าสุดคำนวณจากรายการที่มีอยู่จริง', () async {
      final repo = SleepRepository();
      final until = DateTime(2026, 9, 16);

      await repo.put(night(until, bed: '23:00', wake: '07:00'));
      await repo.put(night(until.subtract(const Duration(days: 1)), bed: '23:00', wake: '05:00'));

      final stats = repo.statsForRecent(days: 7, until: until);
      expect(stats.nightCount, 2);
      expect(stats.averageMinutes, 420);
    });

    test('ยังไม่เคยบันทึกคืนไหน getForDay คืน null', () {
      expect(SleepRepository().getForDay(DateTime(2026, 9, 16)), isNull);
    });
  });
}
