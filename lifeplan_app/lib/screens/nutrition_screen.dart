import 'package:flutter/material.dart';

import '../data/id_gen.dart';
import '../data/repositories/exercise_repository.dart';
import '../data/repositories/goal_settings_repository.dart';
import '../data/repositories/meal_repository.dart';
import '../data/repositories/schedule_repository.dart';
import '../data/repositories/water_repository.dart';
import '../models/exercise_item.dart';
import '../models/goal_settings.dart';
import '../models/life_category.dart';
import '../models/meal_entry.dart';
import '../models/water_log.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/progress_track.dart';
import '../widgets/section_heading.dart';
import 'dart:async';

import '../data/calendar_utils.dart';
import '../data/meal_reminder.dart';
import '../data/notifications.dart';
import '../data/nutrition_history.dart';
import '../data/repositories/app_settings_repository.dart';
import '../models/app_settings.dart';

/// โมดูลทานอาหาร & โภชนาการ — บันทึกมื้ออาหารพร้อมคุณค่าทางโภชนาการ
/// (แคลอรี่ • โปรตีน • แป้ง • ไขมัน • น้ำตาล • วิตามิน), ติดตามการดื่มน้ำ
/// และดูว่ากินสัมพันธ์กับเวลาออกกำลังกายของวันนี้ดีแค่ไหน
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  static const _category = LifeCategory.nutrition;
  static const _dangerColor = Color(0xFFD64545);

  static const _thaiWeekdays = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];

  /// ประมาณการเผาผลาญ 7 kcal ต่อนาที — ใช้สูตรเดียวกับหน้าออกกำลังกาย
  static const _kcalPerExerciseMinute = 7;

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.tryParse(parts.first) ?? 0, minute: int.tryParse(parts.last) ?? 0);
  }

  /// แสดงกรัมแบบสั้น: 30 ไม่ใช่ 30.0 แต่ 12.5 ยังเห็นทศนิยม
  static String _g(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  static String _int(int value) =>
      value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  /// กิจกรรมออกกำลังกายของวันนี้ (ตรงกับชื่อวัน หรือถูกทำเครื่องหมายว่าเป็นวันนี้)
  static List<ExercisePlanItem> _todaysExercise(ExerciseRepository repo) {
    final todayLabel = _thaiWeekdays[DateTime.now().weekday - 1];
    return repo.getAll().where((e) => e.isToday || e.dayLabel == todayLabel).toList();
  }

  Future<bool> _confirmDelete(BuildContext context, MealEntry meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบมื้ออาหารนี้?'),
        content: Text('“${meal.title}” จะถูกลบออกจากบันทึกโภชนาการ'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: _dangerColor),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// ฟอร์มเดียวใช้ทั้งเพิ่มมื้อใหม่ (existing = null) และแก้ไขมื้อเดิม
  Future<void> _openMealForm(BuildContext context, MealRepository repo, {MealEntry? existing}) async {
    final titleController = TextEditingController(text: existing?.title);
    final caloriesController = TextEditingController(text: existing != null ? '${existing.calories}' : '');
    final proteinController = TextEditingController(text: existing != null ? _g(existing.proteinGrams) : '');
    final carbController = TextEditingController(text: existing != null ? _g(existing.carbGrams) : '');
    final fatController = TextEditingController(text: existing != null ? _g(existing.fatGrams) : '');
    final sugarController = TextEditingController(text: existing != null ? _g(existing.sugarGrams) : '');

    MealType selectedType = existing?.type ?? _suggestMealType();
    WorkoutTiming selectedTiming = existing?.workoutTiming ?? WorkoutTiming.none;
    TimeOfDay selectedTime = existing != null ? _parseTime(existing.time) : TimeOfDay.now();
    final selectedVitamins = <Vitamin>{...?existing?.vitamins};

    double parseGrams(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

    await showAppFormSheet(
      context: context,
      title: existing == null ? 'บันทึกมื้ออาหาร' : 'แก้ไขมื้ออาหาร',
      submitLabel: 'บันทึก',
      footerBuilder: existing == null
          ? null
          : (sheetCtx) => SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    if (!await _confirmDelete(sheetCtx, existing)) return;
                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    await repo.delete(existing.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('ลบ “${existing.title}” แล้ว')));
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _dangerColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text('ลบมื้อนี้', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthField(label: 'ชื่อเมนู', hint: 'เช่น ข้าวกล้องอกไก่', controller: titleController),
            const SizedBox(height: 14),
            LabeledDropdown<MealType>(
              label: 'มื้อ',
              value: selectedType,
              options: MealType.values,
              display: (t) => t.label,
              onChanged: (v) => setState(() => selectedType = v!),
            ),
            const SizedBox(height: 14),
            const Text('เวลา', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            const SizedBox(height: 7),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
                if (picked != null) setState(() => selectedTime = picked);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(border: Border.all(color: AppColors.border, width: 1.5), borderRadius: BorderRadius.circular(14)),
                child: Text(_formatTime(selectedTime), style: const TextStyle(fontSize: 14, color: AppColors.text)),
              ),
            ),
            const SizedBox(height: 14),
            AuthField(label: 'พลังงาน (kcal)', hint: 'เช่น 450', controller: caloriesController, keyboardType: TextInputType.number),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AuthField(
                    label: 'โปรตีน (ก.)',
                    hint: '25',
                    controller: proteinController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthField(
                    label: 'แป้ง (ก.)',
                    hint: '60',
                    controller: carbController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AuthField(
                    label: 'ไขมัน (ก.)',
                    hint: '12',
                    controller: fatController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthField(
                    label: 'น้ำตาล (ก.)',
                    hint: '5',
                    controller: sugarController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('วิตามินที่ได้รับ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Vitamin.values.map((v) {
                final selected = selectedVitamins.contains(v);
                return GestureDetector(
                  onTap: () => setState(() => selected ? selectedVitamins.remove(v) : selectedVitamins.add(v)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? _category.color : AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: selected ? _category.color : AppColors.border, width: 1.5),
                    ),
                    child: Text(
                      'วิตามิน ${v.label}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            LabeledDropdown<WorkoutTiming>(
              label: 'ช่วงเวลาเทียบกับการออกกำลังกาย',
              value: selectedTiming,
              options: WorkoutTiming.values,
              display: (t) => t.label,
              onChanged: (v) => setState(() => selectedTiming = v!),
            ),
          ],
        ),
      ),
      onSubmit: () async {
        final title = titleController.text.trim();
        if (title.isEmpty) return;
        await repo.put(MealEntry(
          id: existing?.id ?? newId(),
          title: title,
          type: selectedType,
          time: _formatTime(selectedTime),
          date: existing?.date ?? DateTime.now(),
          calories: int.tryParse(caloriesController.text.replaceAll(',', '').trim()) ?? 0,
          proteinGrams: parseGrams(proteinController),
          carbGrams: parseGrams(carbController),
          fatGrams: parseGrams(fatController),
          sugarGrams: parseGrams(sugarController),
          vitamins: selectedVitamins.toList(),
          workoutTiming: selectedTiming,
        ));
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  /// เดามื้อจากเวลาปัจจุบัน เพื่อให้ฟอร์มเปิดมาถูกมื้อโดยไม่ต้องเลือกเอง
  static MealType _suggestMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) return MealType.breakfast;
    if (hour < 15) return MealType.lunch;
    if (hour < 21) return MealType.dinner;
    return MealType.snack;
  }

  @override
  Widget build(BuildContext context) {
    final mealRepo = MealRepository();
    final waterRepo = WaterRepository();
    final goalsRepo = GoalSettingsRepository();
    final exerciseRepo = ExerciseRepository();
    final scheduleRepo = ScheduleRepository();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            mealRepo.listenable(),
            waterRepo.listenable(),
            goalsRepo.listenable(),
            exerciseRepo.listenable(),
            scheduleRepo.listenable(),
          ]),
          builder: (context, _) {
            final goals = goalsRepo.get();
            final today = DateTime.now();
            final meals = mealRepo.getForDay(today);
            final totals = NutritionTotals.of(meals);
            final water = waterRepo.getForDay(today);

            final todaysExercise = _todaysExercise(exerciseRepo);
            final burnedMinutes = todaysExercise.where((e) => e.isDone).fold<int>(0, (s, e) => s + e.durationMinutes);
            final burnedCalories = burnedMinutes * _kcalPerExerciseMinute;
            final netCalories = totals.calories - burnedCalories;

            final calorieProgress = goals.calorieTarget > 0 ? totals.calories / goals.calorieTarget : 0.0;
            final history = NutritionHistory.of(mealRepo, waterRepo, today: today);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Row(
                  children: [
                    BackButtonCircle(),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('ทานอาหาร & โภชนาการ',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // สรุปพลังงานวันนี้ + เทียบกับที่เผาผลาญจากการออกกำลังกาย
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.nutrition, Color(0xFFA33356)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('พลังงานวันนี้',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                              const SizedBox(height: 6),
                              Text('${_int(totals.calories)} / ${_int(goals.calorieTarget)} kcal',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                            ],
                          ),
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              value: calorieProgress.clamp(0, 1).toDouble(),
                              strokeWidth: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.25),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _HeroStat(value: '${totals.mealCount}', label: 'มื้อที่บันทึก'),
                          const SizedBox(width: 22),
                          _HeroStat(value: '-${_int(burnedCalories)}', label: 'เผาผลาญจากออกกำลังกาย'),
                          const SizedBox(width: 22),
                          _HeroStat(value: _int(netCalories), label: 'พลังงานสุทธิ'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // สารอาหารหลัก
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading(title: 'สารอาหารหลักวันนี้'),
                      const SizedBox(height: 14),
                      _MacroRow(label: 'โปรตีน', value: totals.protein, target: goals.proteinTarget, color: AppColors.nutrition),
                      const SizedBox(height: 12),
                      _MacroRow(label: 'แป้ง / คาร์โบไฮเดรต', value: totals.carbs, target: goals.carbTarget, color: AppColors.crm),
                      const SizedBox(height: 12),
                      _MacroRow(label: 'ไขมัน', value: totals.fat, target: goals.fatTarget, color: AppColors.finance),
                      const SizedBox(height: 12),
                      _MacroRow(
                        label: 'น้ำตาล',
                        value: totals.sugar,
                        target: goals.sugarLimit,
                        color: _dangerColor,
                        isLimit: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // น้ำดื่ม
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeading(title: 'น้ำดื่ม', action: '${water.milliliters} / ${goals.waterTargetMl} มล.'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _WaterButton(icon: Icons.remove_rounded, onTap: () => waterRepo.removeGlass()),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${water.glasses} แก้ว (แก้วละ ${WaterLog.glassMl} มล.)',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                ProgressTrack(
                                  value: goals.waterTargetMl > 0 ? water.milliliters / goals.waterTargetMl : 0,
                                  color: AppColors.finance,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _WaterButton(icon: Icons.add_rounded, onTap: () => waterRepo.addGlass(), filled: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ย้อนหลัง 7 วัน — ข้อมูลเก็บแยกตามวันอยู่แล้ว การ์ดนี้แค่เอามาวางเทียบกัน
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeading(
                        title: 'ย้อนหลัง 7 วัน',
                        action: history.loggedDays.isEmpty ? null : 'เฉลี่ย ${_int(history.averageCalories)} kcal/วัน',
                      ),
                      const SizedBox(height: 12),
                      if (history.loggedDays.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('ยังไม่มีบันทึกย้อนหลัง — บันทึกมื้ออาหารสัก 2–3 วันแล้วกลับมาดูแนวโน้มได้',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                        )
                      else ...[
                        _HistoryChart(history: history, calorieTarget: goals.calorieTarget),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _HistoryStat(
                                value: '${history.daysWithinCalorieTarget(goals.calorieTarget)} / ${history.loggedDays.length}',
                                label: 'วันที่ไม่เกินเป้าพลังงาน',
                              ),
                            ),
                            Expanded(
                              child: _HistoryStat(
                                value: history.averageWaterGlasses.toStringAsFixed(1),
                                label: 'น้ำเฉลี่ย (แก้ว/วัน)',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const _RemindersCard(),
                const SizedBox(height: 16),

                // วิตามิน
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeading(title: 'วิตามิน', action: '${totals.vitamins.length} / ${Vitamin.values.length}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: Vitamin.values.map((v) {
                          final covered = totals.vitamins.contains(v);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: covered ? _category.softColor : AppColors.surface2,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: covered ? _category.color : AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(covered ? Icons.check_rounded : Icons.remove_rounded,
                                    size: 13, color: covered ? _category.color : AppColors.textFaint),
                                const SizedBox(width: 5),
                                Text(
                                  v.label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: covered ? _category.color : AppColors.textFaint,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      if (totals.missingVitamins.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (final v in totals.missingVitamins.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'ยังขาดวิตามิน ${v.label} — ลอง ${v.sourceHint}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text('มื้ออาหารวันนี้', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (meals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('ยังไม่ได้บันทึกมื้ออาหารของวันนี้', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                  )
                else
                  for (final meal in meals)
                    _MealRow(meal: meal, onTap: () => _openMealForm(context, mealRepo, existing: meal)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _openMealForm(context, mealRepo),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: AppColors.textMuted),
                        SizedBox(width: 8),
                        Text('บันทึกมื้ออาหาร',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // โภชนาการรอบการออกกำลังกาย
                _WorkoutNutritionCard(
                  meals: meals,
                  exercise: todaysExercise,
                  burnedCalories: burnedCalories,
                  workoutTimes: scheduleRepo
                      .getForDate(today)
                      .where((e) => e.category == LifeCategory.exercise)
                      .map((e) => '${e.time} ${e.title}')
                      .toList(),
                  goals: goals,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
        ],
      ),
    );
  }
}

/// แถบสารอาหารหนึ่งชนิด — `isLimit` ใช้กับน้ำตาลที่ "ห้ามเกิน" แทนที่จะ "ต้องถึง"
class _MacroRow extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;
  final bool isLimit;

  const _MacroRow({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
    this.isLimit = false,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = target > 0 ? value / target : 0.0;
    final over = isLimit && value > target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              '${NutritionScreen._g(value)} / ${NutritionScreen._g(target)} ก.${isLimit ? ' (ไม่เกิน)' : ''}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: over ? NutritionScreen._dangerColor : AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ProgressTrack(value: ratio.clamp(0, 1).toDouble(), color: color),
        if (over) ...[
          const SizedBox(height: 4),
          Text(
            'เกินเพดานน้ำตาล ${NutritionScreen._g(value - target)} ก.',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: NutritionScreen._dangerColor),
          ),
        ],
      ],
    );
  }
}

class _WaterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _WaterButton({required this.icon, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: filled ? AppColors.finance : AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? AppColors.finance : AppColors.border),
        ),
        child: Icon(icon, size: 20, color: filled ? Colors.white : AppColors.textMuted),
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final MealEntry meal;
  final VoidCallback onTap;

  const _MealRow({required this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 42,
              child: Text(meal.time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textFaint)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(meal.title,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                      ),
                      if (meal.workoutTiming != WorkoutTiming.none)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.exerciseSoft, borderRadius: BorderRadius.circular(999)),
                          child: Text(meal.workoutTiming.shortLabel,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.exercise)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${meal.type.label} • ${NutritionScreen._int(meal.calories)} kcal',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'โปรตีน ${NutritionScreen._g(meal.proteinGrams)} ก. • แป้ง ${NutritionScreen._g(meal.carbGrams)} ก. • '
                    'ไขมัน ${NutritionScreen._g(meal.fatGrams)} ก. • น้ำตาล ${NutritionScreen._g(meal.sugarGrams)} ก.',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint),
                  ),
                  if (meal.vitamins.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'วิตามิน ${meal.vitamins.map((v) => v.label).join(', ')}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.nutrition),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// โภชนาการที่สัมพันธ์กับการออกกำลังกายของวันนี้ — เวลาออก, พลังงานที่เผาผลาญ
/// และเช็คว่ามีมื้อก่อน/หลังออกกำลังกายครบหรือยัง
class _WorkoutNutritionCard extends StatelessWidget {
  final List<MealEntry> meals;
  final List<ExercisePlanItem> exercise;
  final int burnedCalories;
  final List<String> workoutTimes;
  final GoalSettings goals;

  const _WorkoutNutritionCard({
    required this.meals,
    required this.exercise,
    required this.burnedCalories,
    required this.workoutTimes,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final preMeals = meals.where((m) => m.workoutTiming == WorkoutTiming.preWorkout).toList();
    final postMeals = meals.where((m) => m.workoutTiming == WorkoutTiming.postWorkout).toList();
    final plannedMinutes = exercise.fold<int>(0, (s, e) => s + e.durationMinutes);

    return AppCard(
      color: AppColors.exerciseSoft,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: 'โภชนาการสำหรับออกกำลังกาย'),
          const SizedBox(height: 10),
          Text(
            exercise.isEmpty
                ? 'วันนี้ยังไม่มีแผนออกกำลังกาย — กินตามเป้าหมายปกติได้เลย'
                : 'วันนี้มี ${exercise.length} กิจกรรม รวม $plannedMinutes นาที • เผาผลาญแล้ว ${NutritionScreen._int(burnedCalories)} kcal',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          if (workoutTimes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('เวลาออกกำลังกายตามตาราง: ${workoutTimes.join(' • ')}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.exercise)),
          ],
          const SizedBox(height: 14),
          _TimingRow(
            title: 'มื้อก่อนออกกำลังกาย',
            done: preMeals.isNotEmpty,
            detail: preMeals.isNotEmpty
                ? preMeals.map((m) => '${m.time} ${m.title}').join(', ')
                : 'แนะนำแป้งย่อยง่าย 30–60 ก. ก่อนเริ่ม 1–2 ชม.',
          ),
          const SizedBox(height: 10),
          _TimingRow(
            title: 'มื้อหลังออกกำลังกาย',
            done: postMeals.isNotEmpty,
            detail: postMeals.isNotEmpty
                ? postMeals.map((m) => '${m.time} ${m.title}').join(', ')
                : 'แนะนำโปรตีน 20–30 ก. ภายใน 1 ชม. หลังจบ',
          ),
          const SizedBox(height: 10),
          _TimingRow(
            title: 'ดื่มน้ำชดเชย',
            done: burnedCalories == 0,
            detail: burnedCalories == 0
                ? 'ยังไม่ได้ออกกำลังกายวันนี้'
                : 'เพิ่มน้ำอีกราว ${(plannedMinutes / 30).ceil() * 250} มล. จากเป้า ${goals.waterTargetMl} มล.',
          ),
        ],
      ),
    );
  }
}

class _TimingRow extends StatelessWidget {
  final String title;
  final bool done;
  final String detail;

  const _TimingRow({required this.title, required this.done, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: done ? AppColors.exercise : AppColors.surface,
            shape: BoxShape.circle,
            border: done ? null : Border.all(color: AppColors.border, width: 2),
          ),
          alignment: Alignment.center,
          child: done ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(detail, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// แท่งพลังงานของแต่ละวัน — สีแดงคือวันที่เกินเป้า วันที่ยังไม่บันทึกเป็นแท่งจาง
class _HistoryChart extends StatelessWidget {
  final NutritionHistory history;
  final int calorieTarget;

  const _HistoryChart({required this.history, required this.calorieTarget});

  @override
  Widget build(BuildContext context) {
    // สเกลอิงวันที่กินมากสุด แต่ไม่ต่ำกว่าเป้า เพื่อให้เส้นเป้าหมายอยู่ในกรอบเสมอ
    final maxValue = [history.maxCalories, calorieTarget, 1].reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        SizedBox(
          height: 104,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: history.days.map((d) {
              final over = calorieTarget > 0 && d.totals.calories > calorieTarget;
              final ratio = d.isEmpty ? 0.0 : (d.totals.calories / maxValue).clamp(0.04, 1.0);
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      d.isEmpty ? '–' : '${d.totals.calories}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: d.isEmpty ? 3 : 70 * ratio,
                      decoration: BoxDecoration(
                        color: d.isEmpty ? AppColors.border : (over ? NutritionScreen._dangerColor : NutritionScreen._category.color),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: history.days
              .map((d) => Expanded(
                    child: Text(
                      CalendarUtils.weekdayShort[d.date.weekday - 1],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textFaint),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _HistoryStat extends StatelessWidget {
  final String value;
  final String label;

  const _HistoryStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
      ],
    );
  }
}

/// เปิด/ปิดการเตือนมื้ออาหารและดื่มน้ำ
///
/// มื้ออาหารเขียนเป็นกิจกรรมประจำสัปดาห์ในตารางเวลา (แก้/ลบในตารางได้เอง)
/// ส่วนดื่มน้ำเป็นการแจ้งเตือนรายวันตรง ๆ เพราะเตือนถี่จนไม่ควรลงตาราง
class _RemindersCard extends StatefulWidget {
  const _RemindersCard();

  @override
  State<_RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends State<_RemindersCard> {
  final ScheduleRepository _schedule = ScheduleRepository();
  final AppSettingsRepository _settings = AppSettingsRepository();

  static const _intervalOptions = [1, 2, 3, 4];

  void _syncReminders() {
    // ตั้งเตือนใหม่ไม่สำเร็จไม่ควรทำให้การตั้งค่าล้ม — ค่าถูกบันทึกไปแล้ว
    unawaited(NotificationService.syncScheduleReminders().catchError((Object e) {
      debugPrint('ตั้งการแจ้งเตือนใหม่ไม่สำเร็จ: $e');
      return 0;
    }));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleMeal(MealSlot slot, bool on) async {
    if (on) {
      await MealReminder.apply(_schedule, slot, slot.defaultTime);
      _toast('เตือน${slot.label} ${slot.defaultTime} น. ทุกวันแล้ว');
    } else {
      await MealReminder.remove(_schedule, slot);
      _toast('ปิดเตือน${slot.label}แล้ว');
    }
    _syncReminders();
  }

  Future<void> _pickMealTime(MealSlot slot, String current) async {
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null) return;
    final time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await MealReminder.apply(_schedule, slot, time);
    _syncReminders();
    _toast('เตือน${slot.label} $time น. ทุกวันแล้ว');
  }

  Future<void> _saveWater(AppSettings next, String message) async {
    await _settings.save(next);
    _syncReminders();
    _toast(message);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_schedule.listenable(), _settings.listenable()]),
      builder: (context, _) {
        final settings = _settings.get();
        final waterTimes = settings.waterReminderTimes;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(title: 'เตือนมื้ออาหาร & ดื่มน้ำ'),
              const SizedBox(height: 4),
              const Text('มื้ออาหารจะถูกเพิ่มเป็นกิจกรรมประจำในตารางเวลา แก้เวลาได้ทั้งที่นี่และในตาราง',
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textFaint)),
              const SizedBox(height: 10),
              for (final slot in MealSlot.values) ...[
                _ReminderRow(
                  label: slot.label,
                  value: MealReminder.timeOf(_schedule, slot),
                  emptyHint: 'ปิดอยู่',
                  onValueTap: () {
                    final current = MealReminder.timeOf(_schedule, slot);
                    if (current != null) _pickMealTime(slot, current);
                  },
                  on: MealReminder.isOn(_schedule, slot),
                  onChanged: (v) => _toggleMeal(slot, v),
                ),
                const Divider(height: 18, color: AppColors.border),
              ],
              _ReminderRow(
                label: 'ดื่มน้ำ',
                value: waterTimes.isEmpty ? null : '${waterTimes.first}–${waterTimes.last} น. • ${waterTimes.length} ครั้ง/วัน',
                emptyHint: 'ปิดอยู่',
                onValueTap: null,
                on: settings.waterRemindersEnabled,
                onChanged: (v) => _saveWater(
                  settings.copyWith(waterRemindersEnabled: v),
                  v ? 'เตือนดื่มน้ำทุก ${settings.waterIntervalHours} ชั่วโมงแล้ว' : 'ปิดเตือนดื่มน้ำแล้ว',
                ),
              ),
              if (settings.waterRemindersEnabled) ...[
                const SizedBox(height: 10),
                LabeledDropdown<int>(
                  label: 'เตือนทุกกี่ชั่วโมง',
                  value: _intervalOptions.contains(settings.waterIntervalHours) ? settings.waterIntervalHours : 2,
                  options: _intervalOptions,
                  display: (h) => 'ทุก $h ชั่วโมง',
                  onChanged: (v) => _saveWater(
                    settings.copyWith(waterIntervalHours: v),
                    'เตือนดื่มน้ำทุก $v ชั่วโมงแล้ว',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final String label;

  /// null = ยังไม่ได้เปิด
  final String? value;
  final String emptyHint;
  final VoidCallback? onValueTap;
  final bool on;
  final ValueChanged<bool> onChanged;

  const _ReminderRow({
    required this.label,
    required this.value,
    required this.emptyHint,
    required this.onValueTap,
    required this.on,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: value == null ? null : onValueTap,
                child: Row(
                  children: [
                    Text(
                      value ?? emptyHint,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: value == null ? AppColors.textFaint : AppColors.textMuted,
                      ),
                    ),
                    if (value != null && onValueTap != null) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.edit_outlined, size: 13, color: AppColors.textFaint),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Switch(value: on, activeTrackColor: NutritionScreen._category.color, onChanged: onChanged),
      ],
    );
  }
}
