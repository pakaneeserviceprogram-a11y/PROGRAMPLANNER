import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/contact_search.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/client_repository.dart';
import 'package:lifeplan_app/models/client.dart';
import 'package:lifeplan_app/screens/crm_screen.dart';
import 'package:lifeplan_app/screens/prospect_search_screen.dart';

/// ค้นหาผู้มุ่งหวัง — แอปเปิดหน้าค้นหาของเว็บให้ ไม่ได้ดึงข้อมูลมาเก็บเอง
void main() {
  group('ContactSearch', () {
    test('DBD ค้นผ่าน Google แบบจำกัดเว็บคลังข้อมูลธุรกิจ', () {
      final url = ContactSearch.urlFor(ContactSource.dbd, 'บริษัท ตัวอย่าง จำกัด')!;
      expect(url.host, 'www.google.com');
      expect(url.queryParameters['q'], 'บริษัท ตัวอย่าง จำกัด site:${ContactSearch.dbdSite}');
    });

    test('Google / Facebook / Instagram ชี้ไปหน้าค้นหาของแต่ละเว็บ', () {
      expect(ContactSearch.urlFor(ContactSource.google, 'ร้านกาแฟ')!.queryParameters['q'], 'ร้านกาแฟ');

      final fb = ContactSearch.urlFor(ContactSource.facebook, 'คุณสมชาย')!;
      expect(fb.host, 'www.facebook.com');
      expect(fb.path, '/search/top');
      expect(fb.queryParameters['q'], 'คุณสมชาย');

      final ig = ContactSearch.urlFor(ContactSource.instagram, 'somchai')!;
      expect(ig.host, 'www.instagram.com');
      expect(ig.queryParameters['q'], 'somchai');
    });

    test('คำค้นว่างไม่ให้ลิงก์ (ไม่เปิดหน้าเปล่า)', () {
      for (final source in ContactSource.values) {
        expect(ContactSearch.urlFor(source, '   '), isNull, reason: source.name);
        expect(source.label.trim(), isNotEmpty);
        expect(source.hint.trim(), isNotEmpty);
      }
    });

    test('เบอร์โทร: ตัดขีด/ช่องว่างออก และเบอร์สั้นเกินถือว่าใช้ไม่ได้', () {
      expect(ContactSearch.phoneUrl('081-234-5678').toString(), 'tel:0812345678');
      expect(ContactSearch.phoneUrl(' 02 123 4567 ').toString(), 'tel:021234567');
      expect(ContactSearch.phoneUrl('+66 81 234 5678').toString(), 'tel:+66812345678');
      expect(ContactSearch.phoneUrl('1234'), isNull);
      expect(ContactSearch.phoneUrl('ไม่มีเบอร์'), isNull);
    });

    test('ลิงก์โปรไฟล์: เติม https:// ให้ และข้อความธรรมดาไม่ถือเป็นลิงก์', () {
      expect(ContactSearch.profileUrl('facebook.com/somchai').toString(), 'https://facebook.com/somchai');
      expect(ContactSearch.profileUrl('https://www.instagram.com/somchai/').toString(),
          'https://www.instagram.com/somchai/');
      expect(ContactSearch.profileUrl('ไม่มีลิงก์'), isNull);
      expect(ContactSearch.profileUrl('   '), isNull);
    });
  });

  group('หน้าค้นหาผู้มุ่งหวัง', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.clients, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.weeklyReports, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.userProfile, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    testWidgets('พิมพ์ชื่อบริษัทแล้วกดค้น DBD เปิดลิงก์ที่ถูกต้อง', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(MaterialApp(
        home: ProspectSearchScreen(onOpenUrl: (url) async {
          opened.add(url);
          return true;
        }),
      ));

      await tester.enterText(find.byKey(const ValueKey('prospect-query-field')), 'บริษัท ตัวอย่าง จำกัด');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('search-source-dbd')));
      await tester.pumpAndSettle();

      expect(opened.single.queryParameters['q'], contains('site:${ContactSearch.dbdSite}'));
    });

    testWidgets('ยังไม่พิมพ์ชื่อแล้วกดค้น ต้องเตือนแทนที่จะเปิดหน้าเปล่า', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(MaterialApp(
        home: ProspectSearchScreen(onOpenUrl: (url) async {
          opened.add(url);
          return true;
        }),
      ));

      await tester.tap(find.byKey(const ValueKey('search-source-facebook')));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(find.textContaining('พิมพ์ชื่อบริษัทหรือชื่อคน'), findsWidgets);
    });

    testWidgets('บันทึกชื่อที่ค้นเข้ารายชื่อลูกค้าเป็นลูกค้าใหม่', (tester) async {
      await tester.pumpWidget(MaterialApp(home: ProspectSearchScreen(onOpenUrl: (_) async => true)));

      await tester.enterText(find.byKey(const ValueKey('prospect-query-field')), 'คุณสมหญิง ใจงาม');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-as-client')));
      await tester.pumpAndSettle();

      final client = ClientRepository().getAll().single;
      expect(client.name, 'คุณสมหญิง ใจงาม');
      expect(client.stage, ClientStage.newLead);
      expect(client.initials, 'สม'); // ตัดคำว่า "คุณ" ออกก่อนย่อ
      expect(find.textContaining('บันทึก'), findsWidgets);
    });

    testWidgets('บอกข้อจำกัดของ Facebook/Instagram ไว้ในหน้า', (tester) async {
      await tester.pumpWidget(MaterialApp(home: ProspectSearchScreen(onOpenUrl: (_) async => true)));

      await tester.scrollUntilVisible(find.text('สิ่งที่แอปทำและไม่ทำ'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('ไม่เปิดให้แอปภายนอกค้นหารายชื่อคนอัตโนมัติ'), findsOneWidget);
    });
  });

  group('ข้อมูลติดต่อในหน้าลูกค้า', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.clients, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.weeklyReports, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.userProfile, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    test('Client เก็บเบอร์/ลิงก์ และเรคคอร์ดเก่าที่ไม่มีคีย์ยังอ่านได้', () {
      const client = Client(
        id: 'c1',
        name: 'คุณสมชาย',
        initials: 'สม',
        policyLabel: 'ประกันสุขภาพ',
        stage: ClientStage.newLead,
        phone: '081-234-5678',
        profileUrl: 'facebook.com/somchai',
      );
      final back = Client.fromMap(Map<String, dynamic>.from(client.toMap()));
      expect(back.phone, '081-234-5678');
      expect(back.profileUrl, 'facebook.com/somchai');

      final legacy = Client.fromMap({
        'id': 'c2',
        'name': 'เก่า',
        'initials': 'เก',
        'policyLabel': 'x',
        'stage': 'newLead',
      });
      expect(legacy.phone, isNull);
      expect(legacy.profileUrl, isNull);
    });

    testWidgets('กรอกเบอร์และลิงก์ในฟอร์มแล้วบันทึกลง Hive จริง', (tester) async {
      await ClientRepository().put(const Client(
        id: 'c1',
        name: 'คุณสมชาย ใจดี',
        initials: 'สม',
        policyLabel: 'ประกันสุขภาพ • ลูกค้าใหม่',
        stage: ClientStage.newLead,
      ));

      await tester.pumpWidget(const MaterialApp(home: CrmScreen()));
      await tester.pump();

      await tester.scrollUntilVisible(find.byIcon(Icons.edit_outlined), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '08x-xxx-xxxx'), '081-234-5678');
      await tester.enterText(find.widgetWithText(TextField, 'เช่น facebook.com/ชื่อเพจ'), 'facebook.com/somchai');
      await tester.pump();

      final save = find.text('บันทึก');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final client = ClientRepository().getAll().single;
      expect(client.phone, '081-234-5678');
      expect(client.profileUrl, 'facebook.com/somchai');
      // ปุ่มโทร/เปิดโปรไฟล์โผล่ในแถวเมื่อมีข้อมูลแล้ว
      expect(find.byKey(const ValueKey('call-c1')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-c1')), findsOneWidget);
    });

    testWidgets('มีทางเข้าหน้าค้นหาผู้มุ่งหวังจากหน้าลูกค้า', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CrmScreen()));
      await tester.pump();

      final entry = find.byKey(const ValueKey('open-prospect-search'));
      await tester.scrollUntilVisible(entry, 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.text('ค้นหาผู้มุ่งหวัง'), findsOneWidget);
    });
  });
}
