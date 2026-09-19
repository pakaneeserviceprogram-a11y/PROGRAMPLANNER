import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/backup.dart';
import 'package:lifeplan_app/data/backup_reminder.dart';
import 'package:lifeplan_app/data/repositories/app_settings_repository.dart';
import 'package:lifeplan_app/data/repositories/client_repository.dart';
import 'package:lifeplan_app/models/app_settings.dart';
import 'package:lifeplan_app/models/client.dart';
import 'package:lifeplan_app/screens/backup_screen.dart';

/// เตือนให้สำรองข้อมูล — ข้อมูลอยู่ในเครื่องอย่างเดียว หายแล้วกู้ไม่ได้
void main() {
  final now = DateTime(2026, 9, 19, 10);

  group('BackupReminder', () {
    test('ยังไม่เคยสำรองและมีข้อมูลแล้ว = ถึงเวลาเตือน', () {
      const settings = AppSettings();
      expect(BackupReminder.daysSinceBackup(settings, now: now), isNull);
      expect(BackupReminder.isOverdue(settings, hasData: true, now: now), isTrue);
      expect(BackupReminder.bannerMessage(settings, now: now), contains('ยังไม่เคยสำรอง'));
    });

    test('ยังไม่มีข้อมูลก็ไม่ต้องเตือน (ผู้ใช้ใหม่)', () {
      expect(BackupReminder.isOverdue(const AppSettings(), hasData: false, now: now), isFalse);
    });

    test('นับจำนวนวันตั้งแต่สำรองล่าสุด และเตือนเมื่อครบกำหนด', () {
      final sixDays = AppSettings(lastBackupAt: DateTime(2026, 9, 13, 22));
      expect(BackupReminder.daysSinceBackup(sixDays, now: now), 6);
      expect(BackupReminder.isOverdue(sixDays, hasData: true, now: now), isFalse);

      final sevenDays = AppSettings(lastBackupAt: DateTime(2026, 9, 12, 8));
      expect(BackupReminder.daysSinceBackup(sevenDays, now: now), 7);
      expect(BackupReminder.isOverdue(sevenDays, hasData: true, now: now), isTrue);
      expect(BackupReminder.bannerMessage(sevenDays, now: now), contains('7 วันก่อน'));
    });

    test('ปิดการเตือนไว้ = ไม่เตือนและไม่ตั้งแจ้งเตือน', () {
      const off = AppSettings(backupReminderEnabled: false);
      expect(BackupReminder.isOverdue(off, hasData: true, now: now), isFalse);
      expect(BackupReminder.nextReminderAt(off, now: now), isNull);
    });

    test('เวลาแจ้งเตือนถัดไปเป็นสองทุ่มของวันที่ครบกำหนด และอยู่ในอนาคตเสมอ', () {
      // สำรองไว้ 12 ก.ย. + 7 วัน = 19 ก.ย. เวลา 20:00 (ยังไม่ถึงตอน 10 โมง)
      final due = AppSettings(lastBackupAt: DateTime(2026, 9, 12, 8));
      expect(BackupReminder.nextReminderAt(due, now: now), DateTime(2026, 9, 19, 20));

      // ถ้าตอนนี้เลยสองทุ่มไปแล้ว ต้องเลื่อนเป็นวันถัดไป ไม่ใช่ตั้งย้อนหลัง
      expect(
        BackupReminder.nextReminderAt(due, now: DateTime(2026, 9, 19, 21)),
        DateTime(2026, 9, 20, 20),
      );

      // ยังไม่เคยสำรองเลย ก็เตือนรอบสองทุ่มที่จะถึง
      expect(
        BackupReminder.nextReminderAt(const AppSettings(), now: now),
        DateTime(2026, 9, 19, 20),
      );
    });

    test('ค่าเดิมที่บันทึกก่อนมีฟีเจอร์นี้ยังอ่านได้ และค่าใหม่บันทึกกลับได้', () {
      final legacy = AppSettings.fromMap({'scheduleRemindersEnabled': true});
      expect(legacy.backupReminderEnabled, isTrue);
      expect(legacy.backupReminderDays, 7);
      expect(legacy.lastBackupAt, isNull);

      final saved = AppSettings(lastBackupAt: DateTime(2026, 9, 12, 8), backupReminderEnabled: false);
      final back = AppSettings.fromMap(Map<String, dynamic>.from(saved.toMap()));
      expect(back.lastBackupAt, DateTime(2026, 9, 12, 8));
      expect(back.backupReminderEnabled, isFalse);
    });
  });

  group('หน้าสำรองข้อมูล', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        for (final name in [
          ...BackupService.allBoxNames,
        ])
          Hive.openBox<Map>(name, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    testWidgets('แสดงสถานะว่ายังไม่เคยสำรอง และปิดการเตือนได้', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BackupScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่เคยสำรองข้อมูล'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('backup-reminder-switch')));
      await tester.pumpAndSettle();
      expect(AppSettingsRepository().get().backupReminderEnabled, isFalse);
    });

    testWidgets('สำรองแล้วแสดงจำนวนวันตั้งแต่ครั้งล่าสุด', (tester) async {
      await AppSettingsRepository().save(
        AppSettings(lastBackupAt: DateTime.now().subtract(const Duration(days: 3))),
      );

      await tester.pumpWidget(const MaterialApp(home: BackupScreen()));
      await tester.pumpAndSettle();

      expect(find.text('สำรองข้อมูลล่าสุดเมื่อ 3 วันก่อน'), findsOneWidget);
    });

    test('hasDataWorthBackingUp: ว่างเปล่า = ไม่ต้องเตือน, มีลูกค้าแล้ว = ควรเตือน', () async {
      expect(BackupReminder.hasDataWorthBackingUp(), isFalse);

      await ClientRepository().put(const Client(
        id: 'c1',
        name: 'ลูกค้าทดสอบ',
        initials: 'ลท',
        policyLabel: 'x',
        stage: ClientStage.newLead,
      ));
      expect(BackupReminder.hasDataWorthBackingUp(), isTrue);
    });
  });
}
