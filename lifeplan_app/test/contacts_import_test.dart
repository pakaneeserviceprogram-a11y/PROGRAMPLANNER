import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/contacts_import.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/client_repository.dart';
import 'package:lifeplan_app/models/client.dart';
import 'package:lifeplan_app/screens/contacts_import_screen.dart';
import 'package:lifeplan_app/screens/crm_screen.dart';

/// นำเข้าผู้มุ่งหวังจากสมุดโทรศัพท์ + แหล่งที่มาของลูกค้า
void main() {
  const somchai = DeviceContact(id: '1', name: 'สมชาย ใจดี', phone: '081-234-5678');
  const malee = DeviceContact(id: '2', name: 'มาลี ศรีสุข', phone: '0891112222');
  const noPhone = DeviceContact(id: '3', name: 'อนุชา ทองแดง');

  group('ContactsImport.suggest', () {
    test('เรียงตามชื่อ และข้ามรายชื่อที่ไม่มีชื่อ', () {
      final result = ContactsImport.suggest(
        const [somchai, DeviceContact(id: '9', name: '   ', phone: '02'), malee],
        const [],
      );
      expect(result.map((c) => c.name), ['มาลี ศรีสุข', 'สมชาย ใจดี']);
    });

    test('กันซ้ำด้วยเบอร์โทร แม้ชื่อจะเขียนไม่เหมือนกัน', () {
      const existing = Client(
        id: 'c1',
        name: 'คุณสมชาย (ประกัน)',
        initials: 'สม',
        policyLabel: 'x',
        stage: ClientStage.newLead,
        phone: '0812345678',
      );
      final result = ContactsImport.suggest(const [somchai, malee], const [existing]);
      expect(result.map((c) => c.name), ['มาลี ศรีสุข']);
    });

    test('คนไม่มีเบอร์กันซ้ำด้วยชื่อแทน', () {
      const existing = Client(
        id: 'c1',
        name: 'อนุชา ทองแดง',
        initials: 'อน',
        policyLabel: 'x',
        stage: ClientStage.newLead,
      );
      expect(ContactsImport.suggest(const [noPhone], const [existing]), isEmpty);
      expect(ContactsImport.suggest(const [noPhone], const []), hasLength(1));
    });

    test('เบอร์เดียวกันที่มาหลายรายการ (ชื่อซ้ำในเครื่อง) เหลือรายการเดียว', () {
      const duplicate = DeviceContact(id: '4', name: 'สมชาย ใจดี (บ้าน)', phone: '0812345678');
      expect(ContactsImport.suggest(const [somchai, duplicate], const []), hasLength(1));
    });
  });

  group('ContactsImport.search / toClient', () {
    test('ค้นได้ทั้งชื่อและเบอร์ (ไม่สนขีดคั่น)', () {
      const all = [somchai, malee];
      expect(ContactsImport.search(all, 'มาลี').single.id, '2');
      expect(ContactsImport.search(all, '0812345678').single.id, '1');
      expect(ContactsImport.search(all, '081-234').single.id, '1');
      expect(ContactsImport.search(all, ''), hasLength(2));
      expect(ContactsImport.search(all, 'ไม่มีใครชื่อนี้'), isEmpty);
    });

    test('แปลงเป็นลูกค้าใหม่ พร้อมติดแหล่งที่มาว่าสมุดโทรศัพท์', () {
      final client = ContactsImport.toClient(somchai);
      expect(client.name, 'สมชาย ใจดี');
      expect(client.phone, '081-234-5678');
      expect(client.source, ClientSource.phonebook);
      expect(client.stage, ClientStage.newLead);
    });

    test('เบอร์ที่ใช้ไม่ได้ถูกตัดทิ้ง ไม่เก็บขยะไว้ในข้อมูลลูกค้า', () {
      final client = ContactsImport.toClient(const DeviceContact(id: '5', name: 'ทดสอบ', phone: '123'));
      expect(client.phone, isNull);
    });
  });

  group('หน้านำเข้ารายชื่อ', () {
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

    testWidgets('ติ๊กเลือกแล้วนำเข้าเฉพาะคนที่เลือก', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ContactsImportScreen(source: FakeContactsSource(contacts: const [somchai, malee])),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('contact-check-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('นำเข้า 1 รายชื่อ'));
      await tester.pumpAndSettle();

      final clients = ClientRepository().getAll();
      expect(clients, hasLength(1));
      expect(clients.single.name, 'สมชาย ใจดี');
      expect(clients.single.source, ClientSource.phonebook);
    });

    testWidgets('ค้นหาในรายชื่อกรองรายการที่แสดง', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ContactsImportScreen(source: FakeContactsSource(contacts: const [somchai, malee])),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('contact-search-field')), 'มาลี');
      await tester.pumpAndSettle();

      expect(find.text('มาลี ศรีสุข'), findsOneWidget);
      expect(find.text('สมชาย ใจดี'), findsNothing);
    });

    testWidgets('ไม่ได้รับสิทธิ์ต้องบอกวิธีแก้ ไม่ใช่จอว่าง', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ContactsImportScreen(source: FakeContactsSource(granted: false)),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('ยังไม่ได้รับสิทธิ์'), findsOneWidget);
      expect(find.text('ลองใหม่'), findsOneWidget);
    });

    testWidgets('รายชื่อที่เป็นลูกค้าอยู่แล้วไม่ถูกเสนอซ้ำ', (tester) async {
      await ClientRepository().put(const Client(
        id: 'c1',
        name: 'คุณสมชาย',
        initials: 'สม',
        policyLabel: 'x',
        stage: ClientStage.newLead,
        phone: '0812345678',
      ));

      await tester.pumpWidget(MaterialApp(
        home: ContactsImportScreen(source: FakeContactsSource(contacts: const [somchai, malee])),
      ));
      await tester.pumpAndSettle();

      expect(find.text('สมชาย ใจดี'), findsNothing);
      expect(find.text('มาลี ศรีสุข'), findsOneWidget);
    });
  });

  group('แหล่งที่มาของลูกค้า', () {
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

    test('เก็บและอ่านกลับได้ ส่วนลูกค้าเก่าที่ไม่มีคีย์ = ไม่ได้ระบุ', () {
      const client = Client(
        id: 'c1',
        name: 'ก',
        initials: 'ก',
        policyLabel: 'x',
        stage: ClientStage.newLead,
        source: ClientSource.referral,
      );
      expect(Client.fromMap(Map<String, dynamic>.from(client.toMap())).source, ClientSource.referral);

      final legacy = Client.fromMap({'id': 'c2', 'name': 'เก่า', 'initials': 'เก', 'policyLabel': 'x', 'stage': 'newLead'});
      expect(legacy.source, ClientSource.unknown);
    });

    testWidgets('หน้าลูกค้าสรุปจำนวนต่อแหล่งและจำนวนที่ปิดการขายได้', (tester) async {
      final repo = ClientRepository();
      await repo.put(const Client(
        id: 'c1', name: 'ก', initials: 'ก', policyLabel: 'x',
        stage: ClientStage.closedWon, source: ClientSource.referral,
      ));
      await repo.put(const Client(
        id: 'c2', name: 'ข', initials: 'ข', policyLabel: 'x',
        stage: ClientStage.newLead, source: ClientSource.referral,
      ));
      await repo.put(const Client(
        id: 'c3', name: 'ค', initials: 'ค', policyLabel: 'x',
        stage: ClientStage.newLead, source: ClientSource.phonebook,
      ));

      await tester.pumpWidget(const MaterialApp(home: CrmScreen()));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('ลูกค้ามาจากไหน'), 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      expect(find.text('เพื่อน/ลูกค้าแนะนำ'), findsOneWidget);
      expect(find.text('2 ราย'), findsOneWidget);
      expect(find.text('ปิดได้ 1'), findsOneWidget);
      expect(find.text('สมุดโทรศัพท์'), findsOneWidget);
    });
  });
}
