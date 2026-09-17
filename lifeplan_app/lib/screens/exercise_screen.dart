import 'package:flutter/material.dart';

import '../data/id_gen.dart';
import '../data/repositories/exercise_repository.dart';
import '../data/repositories/goal_settings_repository.dart';
import '../models/exercise_item.dart';
import '../models/life_category.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key});

  static const _days = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];

  /// ชื่อที่บันทึกไว้เป็น "วัน • ชื่อกิจกรรม" — ตัดคำนำหน้าวันออกก่อนใส่ในช่องแก้ไข
  static String plainTitle(ExercisePlanItem item) {
    final prefix = '${item.dayLabel} • ';
    return item.title.startsWith(prefix) ? item.title.substring(prefix.length) : item.title;
  }

  /// ฟอร์มเดียวใช้ทั้งเพิ่มกิจกรรมใหม่ (existing = null) และแก้ไขกิจกรรมเดิม
  Future<void> _openItemForm(BuildContext context, ExerciseRepository repo, {ExercisePlanItem? existing}) async {
    final titleController = TextEditingController(text: existing != null ? plainTitle(existing) : null);
    final durationController = TextEditingController(text: '${existing?.durationMinutes ?? 30}');
    ExerciseType selectedType = existing?.type ?? ExerciseType.run;
    String selectedDay = existing != null && _days.contains(existing.dayLabel) ? existing.dayLabel : 'จันทร์';

    await showAppFormSheet(
      context: context,
      title: existing == null ? 'เพิ่มกิจกรรมออกกำลังกาย' : 'แก้ไขกิจกรรมออกกำลังกาย',
      submitLabel: 'บันทึก',
      footerBuilder: existing == null
          ? null
          : (sheetCtx) => FormDeleteButton(
                pageContext: context,
                label: 'ลบกิจกรรมนี้',
                confirmTitle: 'ลบกิจกรรมนี้?',
                confirmMessage: '“${existing.title}” จะถูกลบออกจากแผนออกกำลังกาย',
                doneMessage: 'ลบ “${existing.title}” แล้ว',
                onDelete: () => repo.delete(existing.id),
              ),
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthField(label: 'ชื่อกิจกรรม', hint: 'เช่น วิ่งตอนเช้า', controller: titleController),
            const SizedBox(height: 14),
            LabeledDropdown<String>(
              label: 'วัน',
              value: selectedDay,
              options: _days,
              display: (v) => v,
              onChanged: (v) => setState(() => selectedDay = v!),
            ),
            const SizedBox(height: 14),
            LabeledDropdown<ExerciseType>(
              label: 'ประเภท',
              value: selectedType,
              options: ExerciseType.values,
              display: _typeLabel,
              onChanged: (v) => setState(() => selectedType = v!),
            ),
            const SizedBox(height: 14),
            AuthField(label: 'ระยะเวลา (นาที)', hint: '30', controller: durationController, keyboardType: TextInputType.number),
          ],
        ),
      ),
      onSubmit: () async {
        final title = titleController.text.trim();
        if (title.isEmpty) return;
        final duration = int.tryParse(durationController.text.trim()) ?? 30;
        await repo.put(ExercisePlanItem(
          id: existing?.id ?? newId(),
          title: '$selectedDay • $title',
          type: selectedType,
          dayLabel: selectedDay,
          durationMinutes: duration,
          isDone: existing?.isDone ?? false,
          isToday: existing?.isToday ?? false,
        ));
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  static String _typeLabel(ExerciseType t) => switch (t) {
        ExerciseType.run => 'วิ่ง',
        ExerciseType.strength => 'เวทเทรนนิ่ง',
        ExerciseType.swim => 'ว่ายน้ำ',
        ExerciseType.cycle => 'ปั่นจักรยาน',
        ExerciseType.hike => 'เดินเขา',
        ExerciseType.stretch => 'ยืดเหยียด',
        ExerciseType.other => 'อื่น ๆ',
      };

  @override
  Widget build(BuildContext context) {
    const category = LifeCategory.exercise;
    final repo = ExerciseRepository();
    final goalsRepo = GoalSettingsRepository();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.listenable(), goalsRepo.listenable()]),
          builder: (context, _) {
            final goals = goalsRepo.get();
            final items = repo.getAll();
            final doneCount = items.where((i) => i.isDone).length;
            final totalMinutes = items.where((i) => i.isDone).fold<int>(0, (sum, i) => sum + i.durationMinutes);
            final calories = totalMinutes * 7; // rough estimate for display purposes
            final progress = (doneCount / goals.exerciseWeeklyTarget).clamp(0, 1).toDouble();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Row(
                  children: [
                    BackButtonCircle(),
                    SizedBox(width: 12),
                    Text('ออกกำลังกาย', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [category.color, const Color(0xFF2E8F5E)],
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
                              const Text('เป้าหมายสัปดาห์นี้', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                              const SizedBox(height: 6),
                              Text('$doneCount / ${goals.exerciseWeeklyTarget} ครั้ง', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                            ],
                          ),
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              value: progress,
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
                          _StatColumn(value: '$totalMinutes', label: 'นาทีสัปดาห์นี้'),
                          const SizedBox(width: 24),
                          _StatColumn(value: '$calories', label: 'แคลอรี่'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('แผนสัปดาห์นี้', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (final item in items) ...[
                  GestureDetector(
                    onTap: () => repo.put(item.copyWith(isDone: !item.isDone)),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: item.isDone || item.isToday ? category.softColor : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: item.isToday ? category.color : AppColors.border, width: item.isToday ? 1.5 : 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: item.isDone ? category.color : AppColors.surface2,
                              shape: BoxShape.circle,
                              border: item.isDone ? null : Border.all(color: item.isToday ? category.color : AppColors.border, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: item.isDone ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  item.isDone ? '${item.durationMinutes} นาที • เสร็จแล้ว' : '${item.durationMinutes} นาที',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (item.isToday && !item.isDone)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: category.color, borderRadius: BorderRadius.circular(999)),
                              child: const Text('วันนี้', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          const SizedBox(width: 4),
                          RowEditButton(onTap: () => _openItemForm(context, repo, existing: item)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _openItemForm(context, repo),
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
                        Text('เพิ่มกิจกรรมออกกำลังกาย', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}
