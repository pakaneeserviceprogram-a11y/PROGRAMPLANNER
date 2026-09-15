import 'package:flutter/material.dart';

import '../data/repositories/goal_settings_repository.dart';
import '../models/goal_settings.dart';
import '../models/life_category.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';

/// Lets the user edit the goals that drive progress on the Finance, CRM,
/// Exercise, Dashboard and Progress screens.
class GoalSettingsScreen extends StatefulWidget {
  const GoalSettingsScreen({super.key});

  @override
  State<GoalSettingsScreen> createState() => _GoalSettingsScreenState();
}

class _GoalSettingsScreenState extends State<GoalSettingsScreen> {
  final _repo = GoalSettingsRepository();
  late final TextEditingController _savingController;
  late final TextEditingController _salesController;
  late final TextEditingController _exerciseController;

  @override
  void initState() {
    super.initState();
    final goals = _repo.get();
    _savingController = TextEditingController(text: goals.savingTarget.toStringAsFixed(0));
    _salesController = TextEditingController(text: goals.salesTarget.toStringAsFixed(0));
    _exerciseController = TextEditingController(text: '${goals.exerciseWeeklyTarget}');
  }

  @override
  void dispose() {
    _savingController.dispose();
    _salesController.dispose();
    _exerciseController.dispose();
    super.dispose();
  }

  double? _parsePositive(String text) {
    final value = double.tryParse(text.replaceAll(',', '').trim());
    return value != null && value > 0 ? value : null;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final saving = _parsePositive(_savingController.text);
    final sales = _parsePositive(_salesController.text);
    final exercise = int.tryParse(_exerciseController.text.trim());

    if (saving == null || sales == null) {
      _showMessage('กรุณากรอกเป้าหมายเงินเป็นตัวเลขที่มากกว่า 0');
      return;
    }
    if (exercise == null || exercise < 1 || exercise > 21) {
      _showMessage('เป้าหมายออกกำลังกายต้องอยู่ระหว่าง 1–21 ครั้งต่อสัปดาห์');
      return;
    }

    await _repo.save(GoalSettings(savingTarget: saving, salesTarget: sales, exerciseWeeklyTarget: exercise));
    if (!mounted) return;
    _showMessage('บันทึกเป้าหมายแล้ว');
    Navigator.of(context).maybePop();
  }

  void _resetToDefaults() {
    setState(() {
      _savingController.text = GoalSettings.defaultSavingTarget.toStringAsFixed(0);
      _salesController.text = GoalSettings.defaultSalesTarget.toStringAsFixed(0);
      _exerciseController.text = '${GoalSettings.defaultExerciseWeeklyTarget}';
    });
  }

  @override
  Widget build(BuildContext context) {
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
                Expanded(child: Text('ตั้งค่าเป้าหมาย', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4))),
              ],
            ),
            const SizedBox(height: 6),
            const Text('ใช้คำนวณ % ความคืบหน้าในหน้าแรกและแต่ละด้าน', style: TextStyle(fontSize: 13, color: AppColors.textFaint)),
            const SizedBox(height: 18),
            _GoalCard(
              category: LifeCategory.finance,
              child: AuthField(
                label: 'เป้าหมายเงินออม (บาท)',
                hint: 'เช่น 50000',
                controller: _savingController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(height: 14),
            _GoalCard(
              category: LifeCategory.crm,
              child: AuthField(
                label: 'เป้าหมายยอดขายเบี้ยประกัน (บาท)',
                hint: 'เช่น 250000',
                controller: _salesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(height: 14),
            _GoalCard(
              category: LifeCategory.exercise,
              child: AuthField(
                label: 'ออกกำลังกาย (ครั้งต่อสัปดาห์)',
                hint: 'เช่น 5',
                controller: _exerciseController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'บันทึกเป้าหมาย', onPressed: _save),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _resetToDefaults,
                child: const Text('คืนค่าเริ่มต้น', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final LifeCategory category;
  final Widget child;

  const _GoalCard({required this.category, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 72,
            decoration: BoxDecoration(color: category.color, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(width: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}
