import 'package:flutter/material.dart';

import '../data/nutrition_plan.dart';
import '../data/repositories/body_profile_repository.dart';
import '../data/repositories/exercise_repository.dart';
import '../data/repositories/goal_settings_repository.dart';
import '../models/body_profile.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/progress_track.dart';
import '../widgets/section_heading.dart';

/// คำนวณเป้าหมายโภชนาการจากร่างกายและกิจกรรมจริงของผู้ใช้
/// แล้วให้กดใช้เป็นเป้าหมายของแอปได้ในปุ่มเดียว
class NutritionPlanScreen extends StatefulWidget {
  const NutritionPlanScreen({super.key});

  @override
  State<NutritionPlanScreen> createState() => _NutritionPlanScreenState();
}

class _NutritionPlanScreenState extends State<NutritionPlanScreen> {
  final BodyProfileRepository _bodyRepo = BodyProfileRepository();
  final GoalSettingsRepository _goalsRepo = GoalSettingsRepository();
  final ExerciseRepository _exerciseRepo = ExerciseRepository();

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _birthYearController = TextEditingController();

  late BodyProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = _bodyRepo.get();
    _heightController.text = _profile.heightCm?.toStringAsFixed(0) ?? '';
    _weightController.text = _profile.weightKg?.toStringAsFixed(0) ?? '';
    _birthYearController.text = _profile.birthYear?.toString() ?? '';

    // ผลคำนวณมาจากค่าในช่องกรอก — ต้อง rebuild ทุกครั้งที่พิมพ์
    // (การพิมพ์ใน TextField ไม่ทำให้หน้าจอที่ครอบอยู่ rebuild เอง)
    for (final c in [_heightController, _weightController, _birthYearController]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  /// นาทีออกกำลังกายต่อสัปดาห์จากแผนที่บันทึกไว้ (นับเฉพาะที่ติ๊กว่าทำแล้ว)
  int get _weeklyExerciseMinutes =>
      _exerciseRepo.getAll().where((e) => e.isDone).fold<int>(0, (sum, e) => sum + e.durationMinutes);

  BodyProfile get _currentInput => _profile.copyWith(
        birthYear: int.tryParse(_birthYearController.text.trim()),
        heightCm: double.tryParse(_heightController.text.trim()),
        weightKg: double.tryParse(_weightController.text.trim()),
      );

  Future<void> _save() async {
    final profile = _currentInput;
    if (!profile.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรอกปีเกิด ส่วนสูง และน้ำหนักให้ครบก่อน')),
      );
      return;
    }
    await _bodyRepo.save(profile);
    if (!mounted) return;
    setState(() => _profile = profile);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลร่างกายแล้ว')));
  }

  Future<void> _applyToGoals(NutritionPlan plan) async {
    await _bodyRepo.save(_currentInput);
    await _goalsRepo.save(plan.applyTo(_goalsRepo.get()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ตั้งเป้าใหม่แล้ว: ${plan.calorieTarget} kcal • น้ำ ${plan.waterTargetMl} มล./วัน')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final input = _currentInput;
    final weeklyMinutes = _weeklyExerciseMinutes;
    final plan = NutritionPlanner.of(input, weeklyExerciseMinutes: weeklyMinutes);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Row(
              children: [
                BackButtonCircle(),
                SizedBox(width: 12),
                Expanded(
                  child: Text('โภชนาการที่เหมาะกับคุณ',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('กรอกข้อมูลร่างกาย แล้วแอปจะคำนวณพลังงาน สารอาหาร และน้ำดื่มที่ควรได้ต่อวัน',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textFaint)),
            const SizedBox(height: 18),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(title: 'ข้อมูลร่างกาย'),
                  const SizedBox(height: 12),
                  LabeledDropdown<BodySex>(
                    label: 'เพศ (ใช้ในสูตรคำนวณพลังงาน)',
                    value: input.sex,
                    options: BodySex.values,
                    display: (s) => s.label,
                    onChanged: (v) => setState(() => _profile = _currentInput.copyWith(sex: v)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AuthField(
                          key: const ValueKey('birth-year-field'),
                          label: 'ปีเกิด (ค.ศ.)',
                          hint: 'เช่น 1990',
                          controller: _birthYearController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AuthField(
                          key: const ValueKey('height-field'),
                          label: 'ส่วนสูง (ซม.)',
                          hint: '170',
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AuthField(
                    key: const ValueKey('weight-field'),
                    label: 'น้ำหนัก (กก.)',
                    hint: '65',
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),
                  LabeledDropdown<ActivityLevel>(
                    label: 'ระดับกิจกรรม',
                    value: input.activityLevel,
                    options: ActivityLevel.values,
                    display: (a) => a.label,
                    onChanged: (v) => setState(() => _profile = _currentInput.copyWith(activityLevel: v)),
                  ),
                  if (weeklyMinutes > 0) ...[
                    const SizedBox(height: 6),
                    Text('จากที่บันทึกไว้ สัปดาห์นี้ออกกำลังกายแล้ว $weeklyMinutes นาที',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                  ],
                  const SizedBox(height: 14),
                  LabeledDropdown<WeightGoal>(
                    label: 'เป้าหมายน้ำหนัก',
                    value: input.weightGoal,
                    options: WeightGoal.values,
                    display: (g) => g.label,
                    onChanged: (v) => setState(() => _profile = _currentInput.copyWith(weightGoal: v)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey('save-body-profile'),
                      onPressed: _save,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.nutrition,
                        side: const BorderSide(color: AppColors.nutrition, width: 1.4),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('บันทึกข้อมูลร่างกาย',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (plan == null)
              const AppCard(
                child: Text('กรอกปีเกิด ส่วนสูง และน้ำหนักให้ครบ แล้วผลคำนวณจะขึ้นตรงนี้',
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textFaint)),
              )
            else ...[
              _PlanCard(plan: plan, onApply: () => _applyToGoals(plan)),
              const SizedBox(height: 18),
              _AdviceCard(plan: plan),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final NutritionPlan plan;
  final VoidCallback onApply;

  const _PlanCard({required this.plan, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: 'เป้าหมายที่แนะนำต่อวัน'),
          const SizedBox(height: 4),
          Text('BMI ${plan.bmi} (${plan.bmiLabel}) • ร่างกายใช้พลังงานราว ${plan.tdee} kcal/วัน '
              '(ตอนพัก ${plan.bmr} kcal)',
              style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textFaint)),
          const SizedBox(height: 14),
          _PlanRow(label: 'พลังงาน', value: '${plan.calorieTarget} kcal', color: AppColors.nutrition, emphasis: true),
          const Divider(height: 20, color: AppColors.border),
          _PlanRow(label: 'โปรตีน', value: '${plan.proteinTarget.round()} ก.', color: AppColors.nutrition),
          const SizedBox(height: 10),
          _PlanRow(label: 'แป้ง / คาร์โบไฮเดรต', value: '${plan.carbTarget.round()} ก.', color: AppColors.crm),
          const SizedBox(height: 10),
          _PlanRow(label: 'ไขมัน', value: '${plan.fatTarget.round()} ก.', color: AppColors.finance),
          const SizedBox(height: 10),
          _PlanRow(label: 'น้ำตาล (ไม่เกิน)', value: '${plan.sugarLimit.round()} ก.', color: const Color(0xFFD64545)),
          const Divider(height: 20, color: AppColors.border),
          _PlanRow(
            label: 'น้ำดื่ม',
            value: '${plan.waterTargetMl} มล. (~${(plan.waterTargetMl / 250).round()} แก้ว)',
            color: AppColors.finance,
            emphasis: true,
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'ใช้ค่านี้เป็นเป้าหมายของแอป', onPressed: onApply),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool emphasis;

  const _PlanRow({required this.label, required this.value, required this.color, this.emphasis = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: emphasis ? 14 : 13, fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: emphasis ? 15 : 13.5,
                fontWeight: FontWeight.w800,
                color: emphasis ? color : AppColors.text)),
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  final NutritionPlan plan;

  const _AdviceCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: 'คำแนะนำสำหรับคุณ'),
          const SizedBox(height: 10),
          for (final tip in plan.advice) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5, right: 8),
                  child: Icon(Icons.lightbulb_outline_rounded, size: 15, color: AppColors.nutrition),
                ),
                Expanded(
                  child: Text(tip, style: const TextStyle(fontSize: 12, height: 1.6, color: AppColors.textMuted)),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 2),
          ProgressTrack(value: 1, color: AppColors.border, trackColor: AppColors.border),
          const SizedBox(height: 10),
          const Text(
            'ตัวเลขเหล่านี้เป็นค่าประมาณจากสูตรมาตรฐาน (Mifflin-St Jeor) สำหรับคนทั่วไป — '
            'ถ้ามีโรคประจำตัว ตั้งครรภ์ หรือกำลังคุมอาหารเฉพาะทาง ให้ใช้ตัวเลขจากแพทย์หรือนักกำหนดอาหารแทน',
            style: TextStyle(fontSize: 11, height: 1.5, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}
