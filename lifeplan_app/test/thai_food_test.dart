import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/meal_repository.dart';
import 'package:lifeplan_app/data/thai_food_database.dart';
import 'package:lifeplan_app/models/meal_entry.dart';
import 'package:lifeplan_app/screens/nutrition_screen.dart';

/// เมนูไทยสำเร็จรูป — เลือกแล้วเติมค่าให้ทั้งชุด ผู้ใช้ยังแก้ต่อได้
void main() {
  group('ThaiFoodDatabase', () {
    test('ค้นด้วยคำบางส่วนได้ และชื่อที่ขึ้นต้นด้วยคำค้นมาก่อน', () {
      final results = ThaiFoodDatabase.search('ข้าวผัด');
      expect(results, isNotEmpty);
      expect(results.first.name, startsWith('ข้าวผัด'));

      expect(ThaiFoodDatabase.search('ผัดไทย').map((f) => f.name), contains('ผัดไทยกุ้งสด'));
      expect(ThaiFoodDatabase.search('ส้มตำ').map((f) => f.name), contains('ส้มตำไทย'));
    });

    test('ไม่สนช่องว่างและตัวพิมพ์ และคำค้นว่างไม่คืนอะไร', () {
      expect(ThaiFoodDatabase.search(' ข้าว มันไก่ ').map((f) => f.name), contains('ข้าวมันไก่'));
      expect(ThaiFoodDatabase.search(''), isEmpty);
      expect(ThaiFoodDatabase.search('   '), isEmpty);
      expect(ThaiFoodDatabase.search('พิซซ่าฮาวายเอี้ยน'), isEmpty);
    });

    test('จำกัดจำนวนผลลัพธ์ตาม limit', () {
      expect(ThaiFoodDatabase.search('ข้าว', limit: 3), hasLength(3));
    });

    test('ทุกเมนูมีข้อมูลครบและไม่ติดลบ', () {
      expect(ThaiFoodDatabase.items, isNotEmpty);
      for (final food in ThaiFoodDatabase.items) {
        expect(food.name.trim(), isNotEmpty, reason: 'ชื่อเมนูว่าง');
        expect(food.serving.trim(), isNotEmpty, reason: '${food.name} ไม่ได้บอกหน่วยเสิร์ฟ');
        expect(food.calories, greaterThanOrEqualTo(0), reason: food.name);
        for (final value in [food.protein, food.carbs, food.fat, food.sugar]) {
          expect(value, greaterThanOrEqualTo(0), reason: food.name);
        }
        // น้ำตาลเป็นส่วนหนึ่งของคาร์บ จะมากกว่าคาร์บไม่ได้
        expect(food.sugar, lessThanOrEqualTo(food.carbs), reason: '${food.name}: น้ำตาลมากกว่าแป้ง');
      }
    });

    test('ชื่อเมนูไม่ซ้ำกัน', () {
      final names = ThaiFoodDatabase.items.map((f) => f.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });
  });

  group('ฟอร์มบันทึกมื้ออาหาร', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.mealEntries, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.waterLogs, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.exerciseItems, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.scheduleEvents, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.appSettings, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    testWidgets('ค้นเมนูแล้วเลือก เติมชื่อและสารอาหารให้ทั้งชุด', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NutritionScreen()));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('บันทึกมื้ออาหาร'), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text('บันทึกมื้ออาหาร'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('food-search-field')), 'ข้าวมันไก่');
      await tester.pumpAndSettle();

      final suggestion = find.text('ข้าวมันไก่');
      await tester.ensureVisible(suggestion.last);
      await tester.pumpAndSettle();
      await tester.tap(suggestion.last);
      await tester.pumpAndSettle();

      // ค่าจากฐานข้อมูลถูกเติมลงช่องต่าง ๆ แล้ว
      expect(find.widgetWithText(TextField, 'ข้าวมันไก่'), findsOneWidget);
      expect(find.widgetWithText(TextField, '600'), findsOneWidget);
      expect(find.widgetWithText(TextField, '26'), findsOneWidget);

      final save = find.text('บันทึก');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final meal = MealRepository().getAll().single;
      expect(meal.title, 'ข้าวมันไก่');
      expect(meal.calories, 600);
      expect(meal.proteinGrams, 26);
      expect(meal.vitamins, contains(Vitamin.b));
    });

    testWidgets('ค้นไม่เจอบอกให้กรอกเอง', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NutritionScreen()));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('บันทึกมื้ออาหาร'), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text('บันทึกมื้ออาหาร'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('food-search-field')), 'เมนูที่ไม่มีในฐานข้อมูล');
      await tester.pumpAndSettle();

      expect(find.textContaining('ไม่เจอเมนูนี้'), findsOneWidget);
    });
  });
}
