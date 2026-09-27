import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:lifeplan_app/data/backup.dart';
import 'package:lifeplan_app/data/business_card_scanner.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/medication_reminder.dart';
import 'package:lifeplan_app/data/medicine_label_parser.dart';
import 'package:lifeplan_app/data/repositories/medication_repository.dart';
import 'package:lifeplan_app/models/medication.dart';
import 'package:lifeplan_app/screens/medication_screen.dart';

/// เตือนกินยา — แยกยารักษาโรค (ใส่โรคได้) ออกจากวิตามิน/ยาบำรุง
void main() {
  Medication med({
    required String id,
    required String name,
    MedicationKind kind = MedicationKind.treatment,
    List<String> times = const ['08:00'],
    String? condition,
    List<MedIngredient> ingredients = const [],
    bool active = true,
  }) =>
      Medication(
        id: id,
        name: name,
        kind: kind,
        conditionLabel: condition,
        ingredients: ingredients,
        times: times,
        active: active,
      );

  group('Medication', () {
    test('เก็บ-อ่านกลับได้ครบทุกฟิลด์ รวมส่วนประกอบตัวยา', () {
      final original = Medication(
        id: 'm1',
        name: 'ยาลดความดัน',
        brand: 'Norvasc',
        kind: MedicationKind.treatment,
        conditionLabel: 'ความดันโลหิตสูง',
        ingredients: const [MedIngredient(name: 'Amlodipine', strength: '5 mg')],
        dose: '1 เม็ด',
        times: const ['08:00', '20:00'],
        timing: DoseTiming.afterMeal,
        note: 'ห้ามกินพร้อมเกรปฟรุต',
      );

      final restored = Medication.fromMap(original.toMap());

      expect(restored.name, 'ยาลดความดัน');
      expect(restored.brand, 'Norvasc');
      expect(restored.kind, MedicationKind.treatment);
      expect(restored.conditionLabel, 'ความดันโลหิตสูง');
      expect(restored.ingredients.single.label, 'Amlodipine 5 mg');
      expect(restored.times, ['08:00', '20:00']);
      expect(restored.timing, DoseTiming.afterMeal);
      expect(restored.note, 'ห้ามกินพร้อมเกรปฟรุต');
      expect(restored.dosesPerDay, 2);
      expect(restored.active, isTrue);
    });

    test('ข้อมูลที่บันทึกไว้ก่อนเพิ่มฟิลด์ใหม่ยังอ่านได้ (มีแต่ id กับชื่อ)', () {
      final restored = Medication.fromMap({'id': 'm1', 'name': 'วิตามินซี'});

      expect(restored.kind, MedicationKind.supplement); // เดาว่าเป็นอาหารเสริมไว้ก่อน ปลอดภัยกว่า
      expect(restored.dose, '1 เม็ด');
      expect(restored.times, isEmpty);
      expect(restored.timing, DoseTiming.afterMeal);
      expect(restored.active, isTrue);
    });

    test('สรุปตัวยาอ่านรวมกันได้ และตัวที่ไม่รู้ปริมาณโชว์แค่ชื่อ', () {
      final m = med(
        id: 'm1',
        name: 'ยาแก้ปวด',
        ingredients: const [
          MedIngredient(name: 'Paracetamol', strength: '500 mg'),
          MedIngredient(name: 'Caffeine'),
        ],
      );
      expect(m.ingredientSummary, 'Paracetamol 500 mg • Caffeine');
    });
  });

  group('MedicationReminder', () {
    final morning = med(id: 'a', name: 'ยาเช้า', times: const ['08:00']);
    final twice = med(id: 'b', name: 'วิตามินรวม', kind: MedicationKind.supplement, times: const ['08:00', '20:00']);

    test('กระจายยาออกเป็นรายครั้งของวัน เรียงตามเวลา', () {
      final doses = MedicationReminder.dosesFor([twice, morning], {});

      expect(doses, hasLength(3));
      expect(doses.map((d) => d.time), ['08:00', '08:00', '20:00']);
      expect(doses.every((d) => d.taken), isFalse);
    });

    test('ยาที่ปิดไว้ไม่ขึ้นในรายการของวัน', () {
      final paused = med(id: 'c', name: 'ยาที่จบคอร์สแล้ว', active: false);
      expect(MedicationReminder.dosesFor([paused], {}), isEmpty);
    });

    test('ติ๊กแล้วเฉพาะครั้งนั้นถูกทำเครื่องหมาย ไม่ลามไปเวลาอื่นของยาเดิม', () {
      final doses = MedicationReminder.dosesFor(
        [twice],
        {MedicationLogRepository.doseKey('b', '08:00')},
      );

      expect(doses.firstWhere((d) => d.time == '08:00').taken, isTrue);
      expect(doses.firstWhere((d) => d.time == '20:00').taken, isFalse);
    });

    test('เลยเวลาแล้วยังไม่ติ๊ก = ค้าง / ติ๊กแล้วไม่ค้าง', () {
      final at9 = DateTime(2026, 9, 26, 9);
      final doses = MedicationReminder.dosesFor([twice], {});

      expect(MedicationReminder.overdue(doses, now: at9).map((d) => d.time), ['08:00']);

      final afterTick = MedicationReminder.dosesFor([twice], {MedicationLogRepository.doseKey('b', '08:00')});
      expect(MedicationReminder.overdue(afterTick, now: at9), isEmpty);
    });

    test('ครั้งถัดไปคือครั้งที่ยังไม่ถึงเวลาและยังไม่ติ๊ก', () {
      final doses = MedicationReminder.dosesFor([twice], {});

      expect(MedicationReminder.next(doses, now: DateTime(2026, 9, 26, 7))!.time, '08:00');
      expect(MedicationReminder.next(doses, now: DateTime(2026, 9, 26, 9))!.time, '20:00');
      expect(MedicationReminder.next(doses, now: DateTime(2026, 9, 26, 21)), isNull);
    });

    test('ลำดับการตั้งแจ้งเตือนคงที่ ไม่ขึ้นกับลำดับที่ส่งเข้ามา (id การเตือนจะได้ไม่สลับ)', () {
      final one = MedicationReminder.scheduleEntries([morning, twice]);
      final two = MedicationReminder.scheduleEntries([twice, morning]);

      expect(one.map((e) => '${e.medication.id}@${e.time}'), two.map((e) => '${e.medication.id}@${e.time}'));
      expect(one.map((e) => '${e.medication.id}@${e.time}'), ['a@08:00', 'b@08:00', 'b@20:00']);
    });

    test('ข้อความแจ้งเตือนบอกขนาด ช่วงที่กิน และโรคของยารักษาโรค', () {
      final body = MedicationReminder.notificationBody(
        med(id: 'a', name: 'ยาลดความดัน', condition: 'ความดันโลหิตสูง'),
      );
      expect(body, '1 เม็ด • หลังอาหาร • สำหรับความดันโลหิตสูง');

      final vitamin = MedicationReminder.notificationBody(
        med(id: 'v', name: 'วิตามินซี', kind: MedicationKind.supplement, condition: 'บำรุงผิว'),
      );
      expect(vitamin, '1 เม็ด • หลังอาหาร'); // วิตามินไม่ต้องประกาศโรคบนหน้าจอล็อก
    });
  });

  group('MedicineLabelParser', () {
    test('แกะตัวยาพร้อมปริมาณจากฉลากที่อ่านมาได้', () {
      final label = MedicineLabelParser.parse('''
Paracap
Each tablet contains
Paracetamol 500 mg
Caffeine 65mg
''');

      expect(label.ingredients.map((i) => i.label), ['Paracetamol 500 mg', 'Caffeine 65 mg']);
      expect(label.brand, 'Paracap');
      expect(label.isEmpty, isFalse);
    });

    test('รองรับหน่วยหลายแบบและปรับหน่วยให้เป็นมาตรฐาน', () {
      final label = MedicineLabelParser.parse('''
Vitamin D3 400 IU
Folic Acid 50 ug
Vitamin C 1.5 g
''');

      expect(label.ingredients.map((i) => i.strength), ['400 IU', '50 mcg', '1.5 g']);
    });

    test('ไม่นับตัวยาซ้ำ และข้ามคำมาตรฐานบนกล่อง', () {
      final label = MedicineLabelParser.parse('''
Paracetamol 500 mg
Paracetamol 500 mg
10 tablets
''');

      expect(label.ingredients, hasLength(1));
      expect(label.brand, isNull); // ไม่มีบรรทัดไหนเป็นชื่อการค้า
    });

    test('อ่านอะไรไม่ได้ก็ไม่เดาข้อมูลยาให้', () {
      final label = MedicineLabelParser.parse('');
      expect(label.isEmpty, isTrue);
      expect(label.ingredients, isEmpty);
      expect(label.brand, isNull);
    });

    test('เก็บข้อความดิบไว้ให้ผู้ใช้อ่านส่วนที่แกะไม่ได้', () {
      const raw = 'ยาแก้ปวดลดไข้\nParacetamol 500 mg';
      expect(MedicineLabelParser.parse(raw).rawText, raw);
    });
  });

  group('MedicationRepository', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.medications, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.medicationLog, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    test('ยารักษาโรคขึ้นก่อนวิตามิน และยาที่ปิดไว้ไม่ถูกนับ', () async {
      final repo = MedicationRepository();
      await repo.put(med(id: 'v', name: 'วิตามินซี', kind: MedicationKind.supplement));
      await repo.put(med(id: 't', name: 'ยาลดความดัน'));
      await repo.put(med(id: 'off', name: 'ยาที่จบคอร์ส', active: false));

      expect(repo.getActive().map((m) => m.id), ['t', 'v']);
      expect(repo.byKind(MedicationKind.supplement).map((m) => m.id), ['v']);
    });

    test('บันทึกการกินยาแยกตามวันและแยกตามเวลา', () async {
      final log = MedicationLogRepository();
      final today = DateTime(2026, 9, 26);
      final tomorrow = DateTime(2026, 9, 27);

      expect(await log.toggle(today, 'm1', '08:00'), isTrue);
      expect(log.isTaken(today, 'm1', '08:00'), isTrue);
      expect(log.isTaken(today, 'm1', '20:00'), isFalse);
      expect(log.isTaken(tomorrow, 'm1', '08:00'), isFalse);

      expect(await log.toggle(today, 'm1', '08:00'), isFalse); // กดซ้ำ = ยกเลิก
      expect(log.takenOn(today), isEmpty);
    });

    test('ยาและประวัติการกินยาอยู่ในไฟล์สำรอง และล้างประวัติแล้วรายการยายังอยู่', () {
      expect(BackupService.allBoxNames, contains(HiveBoxes.medications));
      expect(BackupService.allBoxNames, contains(HiveBoxes.medicationLog));
      expect(BackupService.recordBoxNames, contains(HiveBoxes.medicationLog));
      expect(BackupService.recordBoxNames, isNot(contains(HiveBoxes.medications)));
    });
  });

  group('หน้ายาและวิตามิน', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.medications, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.medicationLog, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.appSettings, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    /// ฟอร์มยาสูงกว่าจอในเทสต์ — ต้องเลื่อนหาปุ่มก่อนกด
    Future<void> tapInSheet(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(
        find.text(label),
        250,
        scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Future<void> pumpScreen(WidgetTester tester, {String scanText = '', String? pickedPath = '/tmp/box.jpg'}) async {
      await tester.pumpWidget(MaterialApp(
        home: MedicationScreen(
          recognizer: FakeCardTextRecognizer(scanText),
          pickImage: (ImageSource source) async => pickedPath,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('ยังไม่มียาก็บอกวิธีเริ่ม', (tester) async {
      await pumpScreen(tester);

      expect(find.text('ยังไม่มียาที่ตั้งเวลาไว้ — กด “เพิ่มยาเอง” เพื่อเริ่ม'), findsOneWidget);
      expect(find.text('ยังไม่มียารักษาโรค'), findsOneWidget);
      expect(find.text('ยังไม่มีวิตามินหรือยาบำรุง'), findsOneWidget);
    });

    testWidgets('เพิ่มยารักษาโรคพร้อมโรคที่เป็น แล้วขึ้นในรายการวันนี้', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('med-add')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('med-name-field')), 'ยาลดความดัน');
      await tester.enterText(find.byKey(const ValueKey('med-condition-field')), 'ความดันโลหิตสูง');
      await tapInSheet(tester, 'บันทึก');

      expect(MedicationRepository().getActive().single.conditionLabel, 'ความดันโลหิตสูง');
      expect(find.text('สำหรับความดันโลหิตสูง'), findsOneWidget);
      expect(find.text('ยาลดความดัน'), findsWidgets);
    });

    testWidgets('ไม่ใส่ชื่อยาแล้วกดบันทึก = ไม่บันทึกและบอกให้ใส่ชื่อ', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('med-add')));
      await tester.pumpAndSettle();
      await tapInSheet(tester, 'บันทึก');

      expect(MedicationRepository().getAll(), isEmpty);
      expect(find.text('ใส่ชื่อยาก่อนบันทึก'), findsOneWidget);
    });

    testWidgets('ติ๊กว่ากินแล้ว บันทึกลงประวัติของวันนี้', (tester) async {
      await MedicationRepository().put(med(id: 'm1', name: 'ยาเช้า', times: const ['08:00']));
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('dose-m1-08:00')));
      await tester.pumpAndSettle();

      expect(MedicationLogRepository().isTaken(DateTime.now(), 'm1', '08:00'), isTrue);
      expect(find.text('บันทึกว่ากิน ยาเช้า แล้ว'), findsOneWidget);
    });

    testWidgets('แก้ไขยาเดิมได้จากปุ่มดินสอ', (tester) async {
      await MedicationRepository().put(med(id: 'm1', name: 'ยาเช้า'));
      await pumpScreen(tester);

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('med-name-field')), 'ยาเช้า (แก้แล้ว)');
      await tapInSheet(tester, 'บันทึก');

      final saved = MedicationRepository().getActive().single;
      expect(saved.id, 'm1'); // แก้ของเดิม ไม่ได้สร้างใหม่
      expect(saved.name, 'ยาเช้า (แก้แล้ว)');
    });

    testWidgets('ลบยาออกจากรายการได้', (tester) async {
      await MedicationRepository().put(med(id: 'm1', name: 'ยาเช้า'));
      await pumpScreen(tester);

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tapInSheet(tester, 'ลบยานี้');
      await tester.tap(find.widgetWithText(TextButton, 'ลบ'));
      await tester.pumpAndSettle();

      expect(MedicationRepository().getAll(), isEmpty);
    });

    testWidgets('สแกนกล่องยาแล้วเติมตัวยาที่อ่านได้ลงในฟอร์มให้ตรวจก่อนบันทึก', (tester) async {
      await pumpScreen(tester, scanText: 'Paracap\nParacetamol 500 mg\nCaffeine 65 mg');

      await tester.tap(find.byKey(const ValueKey('med-scan')));
      await tester.pumpAndSettle();

      expect(find.text('Paracetamol 500 mg'), findsOneWidget);
      expect(find.text('Caffeine 65 mg'), findsOneWidget);

      await tapInSheet(tester, 'บันทึก');

      final saved = MedicationRepository().getActive().single;
      expect(saved.name, 'Paracap'); // ชื่อบนกล่องเติมให้เป็นค่าเริ่มต้น
      expect(saved.ingredients.map((i) => i.label), ['Paracetamol 500 mg', 'Caffeine 65 mg']);
    });

    testWidgets('อ่านฉลากไม่ออกก็เปิดฟอร์มเปล่าให้พิมพ์เอง ไม่เดาตัวยาให้', (tester) async {
      await pumpScreen(tester, scanText: 'ยาแก้ปวด ลดไข้');

      await tester.tap(find.byKey(const ValueKey('med-scan')));
      await tester.pumpAndSettle();

      expect(find.text('อ่านได้แต่ชื่อยา ยังไม่เจอบรรทัดตัวยา — เพิ่มเองได้ในฟอร์ม'), findsOneWidget);
      expect(find.text('ยังไม่ได้ใส่'), findsOneWidget);
    });

    testWidgets('ยกเลิกการถ่ายรูปแล้วไม่เปิดฟอร์ม', (tester) async {
      await pumpScreen(tester, pickedPath: null);

      await tester.tap(find.byKey(const ValueKey('med-scan')));
      await tester.pumpAndSettle();

      expect(find.text('เพิ่มยา'), findsNothing);
    });
  });
}
