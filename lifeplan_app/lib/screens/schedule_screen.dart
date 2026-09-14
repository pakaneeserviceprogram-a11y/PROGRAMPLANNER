import 'package:flutter/material.dart';

import '../data/id_gen.dart';
import '../data/repositories/schedule_repository.dart';
import '../models/life_category.dart';
import '../models/schedule_event.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/form_sheet.dart';

const _weekdayLabels = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  Future<void> _openAddForm(BuildContext context, ScheduleRepository repo) async {
    final titleController = TextEditingController();
    final subtitleController = TextEditingController();
    LifeCategory selectedCategory = LifeCategory.work;
    TimeOfDay selectedTime = TimeOfDay.now();

    await showAppFormSheet(
      context: context,
      title: 'เพิ่มกิจกรรมในตารางเวลา',
      submitLabel: 'บันทึก',
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthField(label: 'ชื่อกิจกรรม', hint: 'เช่น ประชุมทีม', controller: titleController),
            const SizedBox(height: 14),
            LabeledDropdown<LifeCategory>(
              label: 'หมวดหมู่',
              value: selectedCategory,
              options: LifeCategory.values,
              display: (c) => c.label,
              onChanged: (v) => setState(() => selectedCategory = v!),
            ),
            const SizedBox(height: 14),
            Text('เวลา', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
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
                child: Text(
                  '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AuthField(label: 'รายละเอียด (ไม่บังคับ)', hint: 'เช่น สถานที่ / ระยะเวลา', controller: subtitleController),
          ],
        ),
      ),
      onSubmit: () async {
        final title = titleController.text.trim();
        if (title.isEmpty) return;
        await repo.put(ScheduleEvent(
          id: newId(),
          time: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
          title: title,
          subtitle: subtitleController.text.trim().isEmpty ? null : subtitleController.text.trim(),
          category: selectedCategory,
        ));
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ScheduleRepository();
    final now = DateTime.now();

    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: repo.listenable(),
        builder: (context, _, _) {
          final events = repo.getAllSortedByTime();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ตารางเวลา', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                        GestureDetector(
                          onTap: () => _openAddForm(context, repo),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: const Icon(Icons.add_rounded, size: 20, color: AppColors.text),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: List.generate(7, (i) {
                        final dayOfMonth = now.day - now.weekday + 1 + i;
                        final selected = i == now.weekday - 1;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text(_weekdayLabels[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textFaint)),
                                const SizedBox(height: 4),
                                Text('$dayOfMonth', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textFaint)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: events.isEmpty
                    ? const Center(child: Text('ยังไม่มีกิจกรรม — กดปุ่ม + เพื่อเพิ่ม', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        itemCount: events.length,
                        itemBuilder: (context, i) {
                          final e = events[i];
                          final isLast = i == events.length - 1;
                          return Dismissible(
                            key: ValueKey(e.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => repo.delete(e.id),
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 18, left: 70),
                              decoration: BoxDecoration(color: const Color(0xFFFCE4DE), borderRadius: BorderRadius.circular(14)),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 18),
                              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB3401E)),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 46, child: Text(e.time, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textFaint))),
                                  const SizedBox(width: 12),
                                  Column(
                                    children: [
                                      Container(width: 10, height: 10, decoration: BoxDecoration(color: e.category.color, shape: BoxShape.circle)),
                                      if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border, margin: const EdgeInsets.symmetric(vertical: 2))),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 18),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: e.category.softColor,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(e.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                          if (e.subtitle != null) ...[
                                            const SizedBox(height: 3),
                                            Text(e.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
