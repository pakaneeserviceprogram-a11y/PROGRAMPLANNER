import 'package:flutter/material.dart';

import '../data/id_gen.dart';
import '../data/repositories/work_task_repository.dart';
import '../models/work_task.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/progress_track.dart';

class WorkScreen extends StatelessWidget {
  const WorkScreen({super.key});

  /// ฟอร์มเดียวใช้ทั้งเพิ่มงานใหม่ (existing = null) และแก้ไขงานเดิม
  Future<void> _openTaskForm(BuildContext context, WorkTaskRepository repo, {WorkTask? existing}) async {
    final titleController = TextEditingController(text: existing?.title);
    final dueController = TextEditingController(text: existing?.dueLabel);
    final progressController = TextEditingController(text: existing?.progressPercent?.toString());
    TaskPriority selectedPriority = existing?.priority ?? TaskPriority.normal;
    TaskStatus selectedStatus = existing?.status ?? TaskStatus.todo;

    await showAppFormSheet(
      context: context,
      title: existing == null ? 'เพิ่มงาน' : 'แก้ไขงาน',
      submitLabel: 'บันทึก',
      footerBuilder: existing == null
          ? null
          : (sheetCtx) => FormDeleteButton(
                pageContext: context,
                label: 'ลบงานนี้',
                confirmTitle: 'ลบงานนี้?',
                confirmMessage: '“${existing.title}” จะถูกลบออกจากรายการงาน',
                doneMessage: 'ลบ “${existing.title}” แล้ว',
                onDelete: () => repo.delete(existing.id),
              ),
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthField(label: 'ชื่องาน', hint: 'เช่น เตรียมเอกสารประชุม', controller: titleController),
            const SizedBox(height: 14),
            LabeledDropdown<TaskStatus>(
              label: 'สถานะ',
              value: selectedStatus,
              options: TaskStatus.values,
              display: statusLabel,
              onChanged: (v) => setState(() => selectedStatus = v!),
            ),
            const SizedBox(height: 14),
            LabeledDropdown<TaskPriority>(
              label: 'ความสำคัญ',
              value: selectedPriority,
              options: TaskPriority.values,
              display: _priorityLabel,
              onChanged: (v) => setState(() => selectedPriority = v!),
            ),
            const SizedBox(height: 14),
            AuthField(label: 'กำหนดส่ง (ไม่บังคับ)', hint: 'เช่น 17:00', controller: dueController),
            if (selectedStatus == TaskStatus.inProgress) ...[
              const SizedBox(height: 14),
              AuthField(
                label: 'ความคืบหน้า % (ไม่บังคับ)',
                hint: 'เช่น 60',
                controller: progressController,
                keyboardType: TextInputType.number,
              ),
            ],
          ],
        ),
      ),
      onSubmit: () async {
        final title = titleController.text.trim();
        if (title.isEmpty) return;
        final due = dueController.text.trim();
        // ความคืบหน้ามีความหมายเฉพาะงานที่กำลังทำ — เปลี่ยนสถานะอื่นแล้วล้างทิ้ง
        final progress = selectedStatus == TaskStatus.inProgress
            ? int.tryParse(progressController.text.trim())?.clamp(0, 100)
            : null;
        await repo.put(WorkTask(
          id: existing?.id ?? newId(),
          title: title,
          status: selectedStatus,
          priority: selectedPriority,
          dueLabel: due.isEmpty ? null : due,
          progressPercent: progress,
        ));
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  static String statusLabel(TaskStatus s) => switch (s) {
        TaskStatus.todo => 'ต้องทำ',
        TaskStatus.inProgress => 'กำลังทำ',
        TaskStatus.done => 'เสร็จแล้ว',
      };

  static String _priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.urgent => 'ด่วน',
        TaskPriority.normal => 'ปกติ',
        TaskPriority.low => 'ไม่เร่งด่วน',
      };

  @override
  Widget build(BuildContext context) {
    final repo = WorkTaskRepository();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: repo.listenable(),
          builder: (context, _, _) {
            final tasks = repo.getAll();
            final todo = tasks.where((t) => t.status == TaskStatus.todo).toList();
            final inProgress = tasks.where((t) => t.status == TaskStatus.inProgress).toList();
            final done = tasks.where((t) => t.status == TaskStatus.done).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  children: [
                    const BackButtonCircle(),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('งานประจำ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4))),
                    GestureDetector(
                      onTap: () => _openTaskForm(context, repo),
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _CountTile(count: '${todo.length}', label: 'ต้องทำ', color: AppColors.workSoft, textColor: AppColors.work)),
                    const SizedBox(width: 12),
                    Expanded(child: _CountTile(count: '${inProgress.length}', label: 'กำลังทำ', color: AppColors.surface2, textColor: AppColors.text)),
                    const SizedBox(width: 12),
                    Expanded(child: _CountTile(count: '${done.length}', label: 'เสร็จแล้ว', color: AppColors.surface2, textColor: AppColors.text)),
                  ],
                ),
                const SizedBox(height: 22),
                const _Label('ต้องทำ'),
                const SizedBox(height: 10),
                if (todo.isEmpty) const _EmptyHint('ยังไม่มีงานที่ต้องทำ'),
                for (final t in todo)
                  _TaskCard(
                    task: t,
                    onToggle: () => repo.put(t.copyWith(status: TaskStatus.done)),
                    onEdit: () => _openTaskForm(context, repo, existing: t),
                    onDelete: () => repo.delete(t.id),
                  ),
                const SizedBox(height: 12),
                const _Label('กำลังดำเนินการ'),
                const SizedBox(height: 10),
                if (inProgress.isEmpty) const _EmptyHint('ไม่มีงานที่กำลังดำเนินการ'),
                for (final t in inProgress)
                  _TaskCard(
                    task: t,
                    highlighted: true,
                    onToggle: () => repo.put(t.copyWith(status: TaskStatus.done)),
                    onEdit: () => _openTaskForm(context, repo, existing: t),
                    onDelete: () => repo.delete(t.id),
                  ),
                const SizedBox(height: 12),
                const _Label('เสร็จแล้ว'),
                const SizedBox(height: 10),
                if (done.isEmpty) const _EmptyHint('ยังไม่มีงานที่เสร็จ'),
                for (final t in done)
                  _TaskCard(
                    task: t,
                    done: true,
                    onToggle: () => repo.put(t.copyWith(status: TaskStatus.todo)),
                    onEdit: () => _openTaskForm(context, repo, existing: t),
                    onDelete: () => repo.delete(t.id),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.4),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
    );
  }
}

class _CountTile extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  final Color textColor;

  const _CountTile({required this.count, required this.label, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final WorkTask task;
  final bool highlighted;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    this.highlighted = false,
    this.done = false,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDeleteDialog(
        context,
        title: 'ลบงานนี้?',
        message: '“${task.title}” จะถูกลบออกจากรายการงาน',
      ),
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: const Color(0xFFFCE4DE), borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB3401E)),
      ),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: highlighted ? AppColors.workSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: highlighted ? AppColors.work : AppColors.border),
          ),
          child: Opacity(
            opacity: done ? 0.55 : 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: done ? AppColors.work : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: done ? AppColors.work : (highlighted ? AppColors.work : AppColors.border), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: done ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (task.progressPercent != null) ...[
                        const SizedBox(height: 8),
                        ProgressTrack(value: task.progressPercent! / 100, color: AppColors.work, trackColor: Colors.white.withValues(alpha: 0.6)),
                      ] else if (!done) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (task.priority == TaskPriority.urgent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(color: const Color(0xFFFCE4DE), borderRadius: BorderRadius.circular(999)),
                                child: const Text('ด่วน', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFB3401E))),
                              ),
                            if (task.dueLabel != null)
                              Text(task.dueLabel!, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                RowEditButton(onTap: onEdit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
