import 'dart:async';

import 'package:flutter/material.dart';

import '../data/id_gen.dart';
import '../data/notifications.dart';
import '../data/repositories/schedule_repository.dart';
import '../models/life_category.dart';
import '../models/schedule_event.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/form_sheet.dart';

const _weekdayLabels = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
const _weekdayFullLabels = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];

/// วันจันทร์ของสัปดาห์ปัจจุบัน — ใช้คำนวณวันที่ที่โชว์ในแถบ 7 วัน (ข้ามเดือน/ปีได้ถูกต้อง)
DateTime _startOfWeek(DateTime now) =>
    DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

const _dangerColor = Color(0xFFB3401E);

String _formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleRepository _repo = ScheduleRepository();

  /// 1 = จันทร์ ... 7 = อาทิตย์ (ตรงกับ DateTime.weekday)
  int _selectedWeekday = DateTime.now().weekday;
  bool _weekView = false;

  void _syncReminders() {
    // ตั้งเตือนใหม่ไม่สำเร็จไม่ควรทำให้การแก้ตารางล้ม — ข้อมูลบันทึกไปแล้ว
    unawaited(NotificationService.syncScheduleReminders().catchError((Object e) {
      debugPrint('ตั้งการแจ้งเตือนใหม่ไม่สำเร็จ: $e');
      return 0;
    }));
  }

  Future<bool> _confirmDelete(BuildContext context, ScheduleEvent e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบกิจกรรม?'),
        content: Text('“${e.title}” วัน${_weekdayFullLabels[e.weekday - 1]} เวลา ${e.time} '
            'จะถูกลบออกจากตารางและการแจ้งเตือน'),
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

  Future<void> _deleteEvent(ScheduleEvent e) async {
    await _repo.delete(e.id);
    _syncReminders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบ “${e.title}” แล้ว')));
  }

  void _selectDay(int weekday) => setState(() {
        _selectedWeekday = weekday;
        _weekView = false;
      });

  /// ฟอร์มเดียวใช้ทั้งเพิ่มใหม่ (existing = null) และแก้ไขกิจกรรมเดิม
  Future<void> _openEventForm(BuildContext context, {ScheduleEvent? existing}) async {
    final titleController = TextEditingController(text: existing?.title);
    final subtitleController = TextEditingController(text: existing?.subtitle);
    LifeCategory selectedCategory = existing?.category ?? LifeCategory.work;
    int selectedWeekday = existing?.weekday ?? _selectedWeekday;
    TimeOfDay selectedTime = existing != null ? _parseTime(existing.time) : TimeOfDay.now();

    await showAppFormSheet(
      context: context,
      title: existing == null ? 'เพิ่มกิจกรรมในตารางเวลา' : 'แก้ไขกิจกรรม',
      submitLabel: 'บันทึก',
      footerBuilder: existing == null
          ? null
          : (sheetCtx) => SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    if (!await _confirmDelete(sheetCtx, existing)) return;
                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    await _deleteEvent(existing);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _dangerColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text('ลบกิจกรรมนี้', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
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
            LabeledDropdown<int>(
              label: 'วัน',
              value: selectedWeekday,
              options: const [1, 2, 3, 4, 5, 6, 7],
              display: (d) => 'วัน${_weekdayFullLabels[d - 1]}',
              onChanged: (v) => setState(() => selectedWeekday = v!),
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
            AuthField(label: 'รายละเอียด (ไม่บังคับ)', hint: 'เช่น สถานที่ / ระยะเวลา', controller: subtitleController),
          ],
        ),
      ),
      onSubmit: () async {
        final title = titleController.text.trim();
        if (title.isEmpty) return;
        await _repo.put(ScheduleEvent(
          id: existing?.id ?? newId(),
          time: _formatTime(selectedTime),
          weekday: selectedWeekday,
          title: title,
          subtitle: subtitleController.text.trim().isEmpty ? null : subtitleController.text.trim(),
          category: selectedCategory,
        ));
        _syncReminders();
        // เด้งไปวันที่เพิ่งบันทึก เพื่อให้เห็นกิจกรรมทันที (กรณีแก้ไขแล้วย้ายวันด้วย)
        if (mounted) _selectDay(selectedWeekday);
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = _startOfWeek(now);

    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: _repo.listenable(),
        builder: (context, _, _) {
          final week = _repo.getWeek();

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
                        Row(
                          children: [
                            _ViewToggle(
                              weekView: _weekView,
                              onChanged: (v) => setState(() => _weekView = v),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => _openEventForm(context),
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
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: List.generate(7, (i) {
                        final date = weekStart.add(Duration(days: i));
                        final selected = !_weekView && i == _selectedWeekday - 1;
                        final isToday = i == now.weekday - 1;
                        final hasEvents = week[i].isNotEmpty;
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _selectDay(i + 1),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: !selected && isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
                              ),
                              child: Column(
                                children: [
                                  Text(_weekdayLabels[i],
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textFaint)),
                                  const SizedBox(height: 4),
                                  Text('${date.day}',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textFaint)),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: hasEvents ? (selected ? Colors.white : AppColors.primary) : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _weekView
                    ? _WeekGrid(
                        week: week,
                        weekStart: weekStart,
                        today: now.weekday,
                        onDayTap: _selectDay,
                        onEventTap: (e) => _openEventForm(context, existing: e),
                      )
                    : _DayTimeline(
                        events: week[_selectedWeekday - 1],
                        weekday: _selectedWeekday,
                        onEventTap: (e) => _openEventForm(context, existing: e),
                        confirmDelete: (e) => _confirmDelete(context, e),
                        onDelete: _deleteEvent,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ปุ่มสลับระหว่างมุมมองรายวันกับตารางทั้งสัปดาห์
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.weekView, required this.onChanged});

  final bool weekView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _segment(label: 'วัน', active: !weekView, onTap: () => onChanged(false)),
          _segment(label: 'สัปดาห์', active: weekView, onTap: () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segment({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.text : AppColors.textFaint,
          ),
        ),
      ),
    );
  }
}

/// ตาราง 7 คอลัมน์ (จันทร์–อาทิตย์) เลื่อนแนวนอนได้ แต่ละคอลัมน์เรียงกิจกรรมตามเวลา
class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.week,
    required this.weekStart,
    required this.today,
    required this.onDayTap,
    required this.onEventTap,
  });

  final List<List<ScheduleEvent>> week;
  final DateTime weekStart;
  final int today;
  final ValueChanged<int> onDayTap;
  final ValueChanged<ScheduleEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(7, (i) {
          final events = week[i];
          final date = weekStart.add(Duration(days: i));
          final isToday = i + 1 == today;
          return Container(
            width: 150,
            margin: EdgeInsets.only(right: i == 6 ? 0 : 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isToday ? AppColors.primary : AppColors.border, width: isToday ? 1.5 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onDayTap(i + 1),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Flexible กัน overflow เพราะชื่อวันยาวไม่เท่ากัน (เช่น "พฤหัสบดี")
                        Flexible(
                          child: Text(_weekdayFullLabels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isToday ? AppColors.primary : AppColors.text)),
                        ),
                        const SizedBox(width: 6),
                        Text('${date.day}/${date.month}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textFaint)),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                if (events.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('ว่าง', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Column(
                      children: [
                        for (final e in events)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onEventTap(e),
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: e.category.softColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border(left: BorderSide(color: e.category.color, width: 3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.time,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(e.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.25)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// มุมมองรายวัน — ไทม์ไลน์ของวันที่เลือก แตะเพื่อแก้ไข ปัดซ้ายเพื่อลบ
class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.events,
    required this.weekday,
    required this.onEventTap,
    required this.confirmDelete,
    required this.onDelete,
  });

  final List<ScheduleEvent> events;
  final int weekday;
  final ValueChanged<ScheduleEvent> onEventTap;
  final Future<bool> Function(ScheduleEvent e) confirmDelete;
  final Future<void> Function(ScheduleEvent e) onDelete;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Text('ยังไม่มีกิจกรรมวัน${_weekdayFullLabels[weekday - 1]} — กดปุ่ม + เพื่อเพิ่ม',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: events.length,
      itemBuilder: (context, i) {
        final e = events[i];
        final isLast = i == events.length - 1;
        return Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => confirmDelete(e),
          onDismissed: (_) => onDelete(e),
          background: Container(
            margin: const EdgeInsets.only(bottom: 18, left: 70),
            decoration: BoxDecoration(color: const Color(0xFFFCE4DE), borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 18),
            child: const Icon(Icons.delete_outline_rounded, color: _dangerColor),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 46,
                    child: Text(e.time,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textFaint))),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: e.category.color, shape: BoxShape.circle)),
                    if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border, margin: const EdgeInsets.symmetric(vertical: 2))),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onEventTap(e),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      decoration: BoxDecoration(
                        color: e.category.softColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
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
                          const SizedBox(width: 8),
                          const Icon(Icons.edit_outlined, size: 16, color: AppColors.textFaint),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
