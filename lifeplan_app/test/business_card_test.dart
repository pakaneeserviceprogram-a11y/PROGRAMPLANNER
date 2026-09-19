import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:lifeplan_app/data/business_card_scanner.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/client_repository.dart';
import 'package:lifeplan_app/models/client.dart';
import 'package:lifeplan_app/screens/business_card_scan_screen.dart';

/// สแกนนามบัตร — ตัวอ่านคืนข้อความดิบมา แล้ว BusinessCardParser แกะเป็นช่อง ๆ
void main() {
  // นามบัตรอังกฤษทั่วไป (ML Kit อ่านได้ดี)
  const englishCard = '''
Somchai Jaidee
Senior Sales Manager
ABC Insurance Co., Ltd.
Tel: 081-234-5678
Email: somchai@abc-insurance.co.th
www.abc-insurance.co.th
''';

  group('BusinessCardParser', () {
    test('แกะชื่อ บริษัท เบอร์ อีเมล เว็บไซต์ จากนามบัตรอังกฤษ', () {
      final fields = BusinessCardParser.parse(englishCard);

      expect(fields.name, 'Somchai Jaidee');
      expect(fields.company, 'ABC Insurance Co., Ltd.');
      expect(fields.phone, '0812345678');
      expect(fields.email, 'somchai@abc-insurance.co.th');
      expect(fields.website, 'www.abc-insurance.co.th');
      expect(fields.isEmpty, isFalse);
    });

    test('ข้ามบรรทัดตำแหน่งงาน ไม่เอามาเป็นชื่อคน', () {
      final fields = BusinessCardParser.parse('Sales Executive\nJohn Smith\nTel 02-123-4567');
      expect(fields.name, 'John Smith');
      expect(fields.phone, '021234567');
    });

    test('เบอร์รูปแบบต่าง ๆ ถูกตัดสัญลักษณ์คั่นทิ้ง', () {
      expect(BusinessCardParser.parse('M. (081) 234-5678').phone, '0812345678');
      expect(BusinessCardParser.parse('Mobile +66 81 234 5678').phone, '+66812345678');
      expect(BusinessCardParser.parse('Tel. 02 123 4567').phone, '021234567');
    });

    test('รูปที่อ่านอะไรไม่ได้เลยต้องคืนค่าว่าง ไม่ใช่ค่ามั่ว', () {
      final fields = BusinessCardParser.parse('');
      expect(fields.isEmpty, isTrue);
      expect(fields.name, isNull);
      expect(fields.phone, isNull);
    });

    test('บริษัทไทยจับได้จากคำว่า บริษัท/จำกัด', () {
      final fields = BusinessCardParser.parse('บริษัท ตัวอย่าง จำกัด\n081-111-2222');
      expect(fields.company, 'บริษัท ตัวอย่าง จำกัด');
      expect(fields.phone, '0811112222');
    });

    test('toClient ติดแหล่งที่มาว่านามบัตร และเก็บเว็บไซต์เป็นลิงก์โปรไฟล์', () {
      final client = BusinessCardParser.toClient(BusinessCardParser.parse(englishCard));

      expect(client.name, 'Somchai Jaidee');
      expect(client.phone, '0812345678');
      expect(client.profileUrl, 'www.abc-insurance.co.th');
      expect(client.source, ClientSource.businessCard);
      expect(client.stage, ClientStage.newLead);
      expect(client.policyLabel, contains('ABC Insurance'));
    });

    test('toClient: ไม่มีชื่อคนให้ใช้ชื่อบริษัทแทน และเบอร์ที่ใช้ไม่ได้ถูกตัดทิ้ง', () {
      final fields = BusinessCardParser.parse('บริษัท ตัวอย่าง จำกัด\n1234');
      final client = BusinessCardParser.toClient(fields);
      expect(client.name, 'บริษัท ตัวอย่าง จำกัด');
      expect(client.phone, isNull);
    });
  });

  group('หน้าสแกนนามบัตร', () {
    setUp(() async {
      await setUpTestHive();
      await Hive.openBox<Map>(HiveBoxes.clients, bytes: Uint8List(0));
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    /// ปุ่มบันทึกอยู่ท้ายหน้า — ListView ยังไม่สร้างจนกว่าจะเลื่อนลงไปถึง
    Future<void> tapSave(WidgetTester tester) async {
      final save = find.text('บันทึกเป็นลูกค้าใหม่');
      await tester.scrollUntilVisible(save, 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    Future<void> pumpScreen(
      WidgetTester tester, {
      String text = englishCard,
      Object? error,
      String? pickedPath = '/tmp/card.jpg',
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: BusinessCardScanScreen(
          recognizer: FakeCardTextRecognizer(text, error: error),
          pickImage: (ImageSource source) async => pickedPath,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('ถ่ายรูปแล้วเติมช่องให้อัตโนมัติ และบันทึกเป็นลูกค้าได้', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('scan-camera')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Somchai Jaidee'), findsOneWidget);
      expect(find.widgetWithText(TextField, '0812345678'), findsOneWidget);
      expect(find.textContaining('somchai@abc-insurance.co.th'), findsOneWidget);

      await tapSave(tester);

      final client = ClientRepository().getAll().single;
      expect(client.name, 'Somchai Jaidee');
      expect(client.phone, '0812345678');
      expect(client.source, ClientSource.businessCard);
    });

    testWidgets('แก้ชื่อที่อ่านมาได้ก่อนบันทึก (เช่น ชื่อไทยที่อ่านไม่ออก)', (tester) async {
      await pumpScreen(tester, text: 'Tel: 081-234-5678');

      await tester.tap(find.byKey(const ValueKey('scan-camera')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('card-name-field')), 'คุณสมชาย ใจดี');
      await tester.pump();
      await tapSave(tester);

      final client = ClientRepository().getAll().single;
      expect(client.name, 'คุณสมชาย ใจดี');
      expect(client.phone, '0812345678');
    });

    testWidgets('ยังไม่ได้ใส่ชื่อแล้วกดบันทึก ต้องเตือนและไม่สร้างลูกค้า', (tester) async {
      await pumpScreen(tester);

      await tapSave(tester);

      expect(ClientRepository().getAll(), isEmpty);
      expect(find.textContaining('ใส่ชื่อลูกค้าก่อน'), findsOneWidget);
    });

    testWidgets('ยกเลิกการเลือกรูปแล้วไม่ต้องขึ้น error', (tester) async {
      await pumpScreen(tester, pickedPath: null);

      await tester.tap(find.byKey(const ValueKey('scan-gallery')));
      await tester.pumpAndSettle();

      expect(find.textContaining('อ่านรูปไม่สำเร็จ'), findsNothing);
      expect(find.textContaining('อ่านข้อมูลจากรูปไม่ได้'), findsNothing);
    });

    testWidgets('อ่านรูปไม่สำเร็จต้องบอกเหตุผล ไม่ใช่เงียบ', (tester) async {
      await pumpScreen(tester, error: Exception('ML Kit พัง'));

      await tester.tap(find.byKey(const ValueKey('scan-camera')));
      await tester.pumpAndSettle();

      expect(find.textContaining('อ่านรูปไม่สำเร็จ'), findsOneWidget);
    });

    testWidgets('รูปที่อ่านอะไรไม่ได้เลย ต้องบอกให้ถ่ายใหม่', (tester) async {
      await pumpScreen(tester, text: '   ');

      await tester.tap(find.byKey(const ValueKey('scan-camera')));
      await tester.pumpAndSettle();

      expect(find.textContaining('อ่านข้อมูลจากรูปไม่ได้'), findsOneWidget);
    });
  });
}
