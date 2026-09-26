import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/ingredient_database.dart';
import 'package:lifeplan_app/data/recipe_calculator.dart';
import 'package:lifeplan_app/data/repositories/meal_repository.dart';
import 'package:lifeplan_app/models/meal_entry.dart';
import 'package:lifeplan_app/screens/recipe_calculator_screen.dart';

/// คำนวณสารอาหารจากวัตถุดิบที่ชั่งเป็นกรัม
void main() {
  Ingredient byName(String name) => IngredientDatabase.items.firstWhere((i) => i.name == name);

  final chicken = byName('อกไก่ไม่มีหนัง'); // 120 kcal, โปรตีน 23 ก. ต่อ 100 ก.
  final egg = byName('ไข่ไก่'); // 143 kcal, โปรตีน 12.6 ก. ต่อ 100 ก. (1 ฟอง 50 ก.)
  final tomato = byName('มะเขือเทศ'); // วิตามิน C 25% ต่อ 100 ก.

  group('IngredientDatabase', () {
    test('ค้นเจอทั้งชื่อเต็มและบางส่วน ไม่สนช่องว่าง', () {
      expect(IngredientDatabase.search('อกไก่').map((i) => i.name), contains('อกไก่ไม่มีหนัง'));
      expect(IngredientDatabase.search('เนื้อ วัว').map((i) => i.name), contains('เนื้อวัวสันใน'));
      expect(IngredientDatabase.search('มะเขือเทศ').first.name, 'มะเขือเทศ');
      expect(IngredientDatabase.search(''), isEmpty);
      expect(IngredientDatabase.search('ทุเรียนทอดกรอบ'), isEmpty);
    });

    test('ครอบคลุมวัตถุดิบหลักที่ผู้ใช้ถามถึง', () {
      final names = IngredientDatabase.items.map((i) => i.name).toList();
      expect(names.any((n) => n.contains('ไก่')), isTrue);
      expect(names.any((n) => n.contains('วัว')), isTrue);
      expect(names.any((n) => n.contains('หมู')), isTrue);
      expect(names.any((n) => n.contains('ปลา')), isTrue);
      expect(names.any((n) => n.contains('ไข่')), isTrue);
      expect(names.any((n) => n.contains('มะเขือเทศ')), isTrue);
    });

    test('ข้อมูลทุกตัวสมเหตุสมผล (ไม่ติดลบ น้ำตาลไม่เกินคาร์บ ชื่อไม่ซ้ำ)', () {
      for (final i in IngredientDatabase.items) {
        expect(i.name.trim(), isNotEmpty);
        for (final v in [i.calories.toDouble(), i.protein, i.carbs, i.fat, i.sugar]) {
          expect(v, greaterThanOrEqualTo(0), reason: i.name);
        }
        expect(i.sugar, lessThanOrEqualTo(i.carbs + 0.001), reason: '${i.name}: น้ำตาลมากกว่าคาร์บ');
        // พลังงานต้องใกล้เคียงกับที่คำนวณจากสารอาหาร (เผื่อคลาด 25% เพราะมีใยอาหาร/ปัดเลข)
        final computed = i.protein * 4 + i.carbs * 4 + i.fat * 9;
        if (i.calories > 20) {
          expect((computed - i.calories).abs() / i.calories, lessThan(0.25), reason: '${i.name}: พลังงานไม่สอดคล้องกับสารอาหาร');
        }
      }
      final names = IngredientDatabase.items.map((i) => i.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('วัตถุดิบที่มีหน่วยนับต้องบอกน้ำหนักต่อหน่วยด้วย', () {
      for (final i in IngredientDatabase.items) {
        if (i.unitHint != null) expect(i.unitGrams, isNotNull, reason: i.name);
        if (i.unitGrams != null) expect(i.unitGrams, greaterThan(0), reason: i.name);
      }
    });
  });

  group('RecipeCalculator', () {
    test('คิดตามสัดส่วนน้ำหนักจริง (ค่าในตารางเป็นต่อ 100 ก.)', () {
      final item = RecipeItem(ingredient: chicken, grams: 150);
      expect(item.calories, closeTo(180, 0.01)); // 120 × 1.5
      expect(item.protein, closeTo(34.5, 0.01)); // 23 × 1.5
    });

    test('รวมหลายวัตถุดิบเป็นยอดเดียว', () {
      final totals = RecipeCalculator.totalsOf([
        RecipeItem(ingredient: chicken, grams: 100),
        RecipeItem(ingredient: egg, grams: 50), // ไข่ 1 ฟอง
      ]);

      expect(totals.grams, 150);
      expect(totals.calories, closeTo(120 + 71.5, 0.01));
      expect(totals.protein, closeTo(23 + 6.3, 0.01));
      expect(totals.isEmpty, isFalse);
    });

    test('รวมวิตามินข้ามวัตถุดิบ และคิดตามน้ำหนัก', () {
      final totals = RecipeCalculator.totalsOf([
        RecipeItem(ingredient: tomato, grams: 200), // วิตามิน C 25% ต่อ 100 ก. → 50%
        RecipeItem(ingredient: egg, grams: 100), // วิตามิน D 20%
      ]);

      expect(totals.vitaminPercent[Vitamin.c], closeTo(50, 0.01));
      expect(totals.vitaminPercent[Vitamin.d], closeTo(20, 0.01));
    });

    test('สัดส่วนพลังงานจากสารอาหารรวมกันได้ 100%', () {
      final split = RecipeCalculator.totalsOf([
        RecipeItem(ingredient: chicken, grams: 200),
        RecipeItem(ingredient: byName('น้ำมันพืช'), grams: 10),
      ]).energySplit;

      expect(split.protein + split.carbs + split.fat, closeTo(1.0, 0.001));
      expect(split.fat, greaterThan(split.carbs));
    });

    test('จานว่างไม่พังและไม่ให้ค่ามั่ว', () {
      final totals = RecipeCalculator.totalsOf([]);
      expect(totals.isEmpty, isTrue);
      expect(totals.calories, 0);
      expect(totals.energySplit.protein, 0);
      expect(totals.notableVitamins(), isEmpty);
    });

    test('วิตามินที่ได้น้อยกว่าเกณฑ์ไม่ถูกนับว่า "ได้วิตามินนี้"', () {
      // มะเขือเทศ 20 ก. → วิตามิน C แค่ 5%
      final totals = RecipeCalculator.totalsOf([RecipeItem(ingredient: tomato, grams: 20)]);
      expect(totals.vitaminPercent[Vitamin.c], closeTo(5, 0.01));
      expect(totals.notableVitamins(), isEmpty);
      expect(totals.notableVitamins(threshold: 4).map((e) => e.key), contains(Vitamin.c));
    });

    test('แปลงเป็นมื้ออาหารพร้อมติดธงเฉพาะวิตามินที่ได้จริง', () {
      final meal = RecipeCalculator.toMealEntry(
        [
          RecipeItem(ingredient: chicken, grams: 150),
          RecipeItem(ingredient: tomato, grams: 200),
        ],
        title: 'อกไก่ + มะเขือเทศ',
        type: MealType.lunch,
        time: '12:30',
        date: DateTime(2026, 9, 26),
      );

      expect(meal.title, 'อกไก่ + มะเขือเทศ');
      expect(meal.calories, 216); // 180 + 36
      expect(meal.proteinGrams, closeTo(36.3, 0.05));
      expect(meal.vitamins, contains(Vitamin.c)); // มะเขือเทศ 200 ก. = 50%
      expect(meal.vitamins, contains(Vitamin.b)); // อกไก่ 150 ก. = 60%
      expect(meal.vitamins, isNot(contains(Vitamin.d)));
    });

    test('เดาชื่อมื้อจากวัตถุดิบที่หนักที่สุดก่อน', () {
      final title = RecipeCalculator.suggestTitle([
        RecipeItem(ingredient: egg, grams: 50),
        RecipeItem(ingredient: chicken, grams: 200),
      ]);
      expect(title, 'อกไก่ไม่มีหนัง + ไข่ไก่');
      expect(RecipeCalculator.suggestTitle([]), '');
    });
  });

  group('หน้าคำนวณจากวัตถุดิบ', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.mealEntries, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    testWidgets('ค้นแล้วแตะเพื่อเพิ่ม เห็นยอดรวมทันที', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecipeCalculatorScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('ingredient-search-field')), 'อกไก่');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ingredient-อกไก่ไม่มีหนัง')));
      await tester.pumpAndSettle();

      // ค่าเริ่มต้น 1 ชิ้น = 120 ก. → 144 kcal
      expect(find.text('144'), findsOneWidget);
      expect(find.textContaining('รวม 120 ก.'), findsOneWidget);
    });

    testWidgets('เพิ่มวัตถุดิบเดิมซ้ำ = บวกน้ำหนักในบรรทัดเดิม', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecipeCalculatorScreen()));
      await tester.pumpAndSettle();

      for (var i = 0; i < 2; i++) {
        await tester.enterText(find.byKey(const ValueKey('ingredient-search-field')), 'ไข่ไก่');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('ingredient-ไข่ไก่')));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(const ValueKey('item-ไข่ไก่')), findsOneWidget);
      expect(find.textContaining('รวม 100 ก.'), findsOneWidget); // 50 + 50
    });

    testWidgets('แก้น้ำหนักแล้วยอดรวมเปลี่ยนตาม', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecipeCalculatorScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('ingredient-search-field')), 'อกไก่');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ingredient-อกไก่ไม่มีหนัง')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('item-อกไก่ไม่มีหนัง')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('grams-field')), '200');
      await tester.pumpAndSettle();
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      expect(find.text('240'), findsOneWidget); // 120 × 2
    });

    testWidgets('บันทึกเป็นมื้ออาหารแล้วเข้าบันทึกโภชนาการจริง', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecipeCalculatorScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('ingredient-search-field')), 'มะเขือเทศ');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ingredient-มะเขือเทศ')));
      await tester.pumpAndSettle();

      final save = find.text('บันทึกเป็นมื้ออาหาร');
      await tester.scrollUntilVisible(save, 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      await tester.tap(find.text('บันทึก'));
      await tester.pumpAndSettle();

      final meal = MealRepository().getAll().single;
      expect(meal.title, 'มะเขือเทศ');
      expect(meal.calories, 22); // 18 × 1.2 (120 ก.)
      expect(meal.vitamins, contains(Vitamin.c));
    });
  });
}
