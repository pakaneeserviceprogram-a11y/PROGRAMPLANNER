import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/nutrition_plan.dart';
import 'package:lifeplan_app/data/repositories/body_profile_repository.dart';
import 'package:lifeplan_app/data/repositories/exercise_repository.dart';
import 'package:lifeplan_app/data/repositories/goal_settings_repository.dart';
import 'package:lifeplan_app/models/body_profile.dart';
import 'package:lifeplan_app/models/exercise_item.dart';
import 'package:lifeplan_app/models/goal_settings.dart';
import 'package:lifeplan_app/screens/nutrition_plan_screen.dart';

/// เป้าหมายโภชนาการเฉพาะบุคคล — คำนวณจากน้ำหนัก/ส่วนสูง/อายุ/เพศ/กิจกรรม
void main() {
  final today = DateTime(2026, 9, 19);

  // ชาย เกิด 1990 (อายุ 36) สูง 175 หนัก 70 ออกกำลังกายปานกลาง
  final man = BodyProfile(
    sex: BodySex.male,
    birthYear: 1990,
    heightCm: 175,
    weightKg: 70,
    activityLevel: ActivityLevel.moderate,
  );

  group('NutritionPlanner', () {
    test('คำนวณ BMR/TDEE ตามสูตร Mifflin-St Jeor', () {
      final plan = NutritionPlanner.of(man, now: today)!;

      // 10×70 + 6.25×175 − 5×36 + 5 = 1618.75 → 1619
      expect(plan.bmr, 1619);
      // × 1.55 (ปานกลาง) = 2509.06 → 2509
      expect(plan.tdee, 2509);
      // คงน้ำหนัก = เท่ากับ TDEE
      expect(plan.calorieTarget, 2509);
    });

    test('ผู้หญิงใช้ค่าคงที่ต่างกัน 166 kcal ตามสูตร', () {
      final woman = man.copyWith(sex: BodySex.female);
      final planMan = NutritionPlanner.of(man, now: today)!;
      final planWoman = NutritionPlanner.of(woman, now: today)!;
      expect(planMan.bmr - planWoman.bmr, 166);
    });

    test('เป้าหมายลดน้ำหนักลด 15% เพิ่มน้ำหนักเพิ่ม 10% จาก TDEE', () {
      final lose = NutritionPlanner.of(man.copyWith(weightGoal: WeightGoal.lose), now: today)!;
      final gain = NutritionPlanner.of(man.copyWith(weightGoal: WeightGoal.gain), now: today)!;

      expect(lose.calorieTarget, (lose.tdee * 0.85).round());
      expect(gain.calorieTarget, (gain.tdee * 1.1).round());
      expect(lose.calorieTarget, lessThan(lose.tdee));
    });

    test('โปรตีนต่อน้ำหนักตัวเพิ่มตามระดับกิจกรรม', () {
      final sedentary = NutritionPlanner.of(man.copyWith(activityLevel: ActivityLevel.sedentary), now: today)!;
      final veryActive = NutritionPlanner.of(man.copyWith(activityLevel: ActivityLevel.veryActive), now: today)!;

      expect(sedentary.proteinTarget, 70 * 1.2);
      expect(veryActive.proteinTarget, 70 * 2.0);
    });

    test('สัดส่วนพลังงานจากไขมัน 25% และน้ำตาลไม่เกิน 10%', () {
      final plan = NutritionPlanner.of(man, now: today)!;
      expect(plan.fatTarget * 9 / plan.calorieTarget, closeTo(0.25, 0.01));
      expect(plan.sugarLimit * 4 / plan.calorieTarget, closeTo(0.10, 0.01));
    });

    test('น้ำดื่ม = 35 มล./กก. บวกชดเชยการออกกำลังกาย และปัดขึ้นหลักร้อย', () {
      final resting = NutritionPlanner.of(man, now: today)!;
      expect(resting.waterTargetMl, 2500); // 70×35 = 2450 → ปัดขึ้น 2500

      // ออกกำลังกาย 210 นาที/สัปดาห์ = 30 นาที/วัน → +500 มล.
      final active = NutritionPlanner.of(man, weeklyExerciseMinutes: 210, now: today)!;
      expect(active.waterTargetMl, 3000);
      expect(active.waterTargetMl, greaterThan(resting.waterTargetMl));
    });

    test('BMI และการแปลผลตามเกณฑ์เอเชีย', () {
      expect(NutritionPlanner.of(man, now: today)!.bmi, 22.9);
      expect(NutritionPlanner.of(man, now: today)!.bmiLabel, 'สมส่วน');

      final heavy = NutritionPlanner.of(man.copyWith(weightKg: 85), now: today)!;
      expect(heavy.bmiLabel, 'อ้วนระดับ 1');

      final thin = NutritionPlanner.of(man.copyWith(weightKg: 50), now: today)!;
      expect(thin.bmiLabel, 'ผอมกว่าเกณฑ์');
    });

    test('ข้อมูลไม่ครบหรือค่าติดลบ = คำนวณไม่ได้ (คืน null แทนค่ามั่ว)', () {
      expect(NutritionPlanner.of(const BodyProfile(), now: today), isNull);
      expect(NutritionPlanner.of(man.copyWith(weightKg: 0), now: today), isNull);
      expect(NutritionPlanner.of(BodyProfile(birthYear: 2030, heightCm: 170, weightKg: 60), now: today), isNull);
    });

    test('คำแนะนำอ้างอิงตัวเลขของผู้ใช้เอง', () {
      final heavy = NutritionPlanner.of(
        man.copyWith(weightKg: 85, weightGoal: WeightGoal.lose),
        weeklyExerciseMinutes: 60,
        now: today,
      )!;

      expect(heavy.advice.any((t) => t.contains('BMI อยู่เกณฑ์ท้วม')), isTrue);
      expect(heavy.advice.any((t) => t.contains('150 นาที')), isTrue);
      expect(heavy.advice.any((t) => t.contains('โปรตีนเป้าหมาย')), isTrue);
    });

    test('applyTo ทับเฉพาะเป้าโภชนาการ ไม่ยุ่งกับเป้าเงิน/ขาย/นอน', () {
      final plan = NutritionPlanner.of(man, now: today)!;
      const current = GoalSettings(savingTarget: 99999, salesTarget: 88888, sleepTargetMinutes: 420);
      final updated = plan.applyTo(current);

      expect(updated.calorieTarget, plan.calorieTarget);
      expect(updated.waterTargetMl, plan.waterTargetMl);
      expect(updated.savingTarget, 99999);
      expect(updated.salesTarget, 88888);
      expect(updated.sleepTargetMinutes, 420);
    });
  });

  group('BodyProfile', () {
    test('อายุคิดจากปีเกิด และบันทึก/อ่านกลับได้ครบ', () {
      expect(man.age(now: today), 36);
      expect(man.isComplete, isTrue);
      expect(const BodyProfile().isComplete, isFalse);

      final back = BodyProfile.fromMap(Map<String, dynamic>.from(man.toMap()));
      expect(back.sex, BodySex.male);
      expect(back.birthYear, 1990);
      expect(back.heightCm, 175);
      expect(back.weightKg, 70);
      expect(back.activityLevel, ActivityLevel.moderate);
    });
  });

  group('หน้าโภชนาการที่เหมาะกับคุณ', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.bodyProfile, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.goalSettings, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.exerciseItems, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    testWidgets('ยังไม่กรอกข้อมูล ต้องชวนให้กรอกแทนโชว์ตัวเลขมั่ว', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NutritionPlanScreen()));
      await tester.pumpAndSettle();

      final hint = find.textContaining('กรอกปีเกิด ส่วนสูง และน้ำหนักให้ครบ');
      await tester.scrollUntilVisible(hint, 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(hint, findsOneWidget);
    });

    testWidgets('กรอกครบแล้วเห็นผลคำนวณ และกดใช้เป็นเป้าหมายได้', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NutritionPlanScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('birth-year-field')), '1990');
      await tester.enterText(find.byKey(const ValueKey('height-field')), '175');
      await tester.enterText(find.byKey(const ValueKey('weight-field')), '70');
      await tester.pumpAndSettle();

      final apply = find.text('ใช้ค่านี้เป็นเป้าหมายของแอป');
      await tester.scrollUntilVisible(find.text('เป้าหมายที่แนะนำต่อวัน'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('เป้าหมายที่แนะนำต่อวัน'), findsOneWidget);
      await tester.scrollUntilVisible(apply, 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(apply);
      await tester.pumpAndSettle();

      final goals = GoalSettingsRepository().get();
      final expected = NutritionPlanner.of(
        BodyProfile(birthYear: 1990, heightCm: 175, weightKg: 70),
      )!;
      expect(goals.calorieTarget, expected.calorieTarget);
      expect(goals.waterTargetMl, expected.waterTargetMl);
      // ข้อมูลร่างกายถูกบันทึกไว้ด้วย จะได้ไม่ต้องกรอกใหม่รอบหน้า
      expect(BodyProfileRepository().get().weightKg, 70);
    });

    testWidgets('นาทีออกกำลังกายที่บันทึกไว้ถูกนำมาคิดเป็นน้ำที่ต้องดื่มเพิ่ม', (tester) async {
      await ExerciseRepository().put(const ExercisePlanItem(
        id: 'e1',
        title: 'วิ่ง',
        type: ExerciseType.run,
        dayLabel: 'จันทร์',
        durationMinutes: 210,
        isDone: true,
      ));

      await tester.pumpWidget(const MaterialApp(home: NutritionPlanScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('birth-year-field')), '1990');
      await tester.enterText(find.byKey(const ValueKey('height-field')), '175');
      await tester.enterText(find.byKey(const ValueKey('weight-field')), '70');
      await tester.pumpAndSettle();

      expect(find.textContaining('สัปดาห์นี้ออกกำลังกายแล้ว 210 นาที'), findsOneWidget);

      final water = find.textContaining('3000 มล.');
      await tester.scrollUntilVisible(water, 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(water, findsOneWidget);
    });
  });
}
