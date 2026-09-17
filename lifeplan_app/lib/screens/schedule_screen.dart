import 'dart:async';

import 'package:flutter/material.dart';

import '../data/calendar_utils.dart';
import '../data/id_gen.dart';
import '../data/notifications.dart';
import '../data/repositories/schedule_repository.dart';
import '../models/life_category.dart';
import '../models/schedule_event.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/form_sheet.dart';

const _weekdayLabels = CalendarUtils.weekdayShort;
const _weekdayFullLabels = CalendarUtils.weekdayFull;

const _dangerColor = Color(0xFFB3401E);

String _formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// "จ, อ, พ" — ใช้บอกว่ากิจกรรมชุดนี้อยู่วันไหนบ้าง
String _weekdayList(Iterable<int> weekdays) {
  final sorted = weekdays.toSet().toList()..sort();
  if (sorted.length == 7) return 'ทุกวัน';
  return sorted.map((d) => _weekdayLabels[d - 1]).join(', ');
}

enum _ScheduleView { day, week, month, year }

/// กิจกรรมทั้งหมดที่เกิดขึ้นในวันที่หนึ่ง (ประจำสัปดาห์ + นัดหมายเฉพาะวันที่) เรียงตามเวลา
typedef _EventsOn = List<ScheduleEvent> Function(DateTime date);

enum _DeleteChoice { cancel, single, series }

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleRepository _repo = ScheduleRepository();

  /// วันที่ที่เลือกอยู่ — มุมมองวัน/สัปดาห์ใช้สัปดาห์ของวันนี้ ส่วนเดือนใช้แสดงรายการใต้ปฏิทิน
  DateTime _selectedDate = CalendarUtils.dateOnly(DateTime.now());

  /// เดือนที่เปิดดูในมุมมองเดือน (วันที่ 1 ของเดือน) และปีที่เปิดดูในมุมมองปี
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  _ScheduleView _view = _ScheduleView.day;

  int get _selectedWeekday => _selectedDate.weekday;

  void _syncReminders() {
    // ตั้งเตือนใหม่ไม่สำเร็จไม่ควรทำให้การแก้ตารางล้ม — ข้อมูลบันทึกไปแล้ว
    unawaited(
      NotificationService.syncScheduleReminders().catchError((Object e) {
        debugPrint('ตั้งการแจ้งเตือนใหม่ไม่สำเร็จ: $e');
        return 0;
      }),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDelete(BuildContext context, ScheduleEvent e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบกิจกรรม?'),
        content: Text(
          '“${e.title}” ${e.isOneOff ? 'วันที่ ${CalendarUtils.thaiDate(e.date!)}' : 'วัน${_weekdayFullLabels[e.weekday - 1]}'} เวลา ${e.time} '
          'จะถูกลบออกจากตารางและการแจ้งเตือน',
        ),
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

  /// กิจกรรมที่มีสำเนาอยู่วันอื่น — ถามว่าจะลบเฉพาะวันนี้หรือทั้งชุด
  Future<_DeleteChoice> _confirmDeleteSeries(BuildContext context, ScheduleEvent e, List<ScheduleEvent> series) async {
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบกิจกรรม?'),
        content: Text(
          '“${e.title}” มีอยู่ ${series.length} วัน (${_weekdayList(series.map((s) => s.weekday))})\n'
          'จะลบเฉพาะวัน${_weekdayFullLabels[e.weekday - 1]} หรือลบทุกวันในชุดนี้?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(_DeleteChoice.cancel), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DeleteChoice.single),
            style: TextButton.styleFrom(foregroundColor: _dangerColor),
            child: const Text('ลบเฉพาะวันนี้'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DeleteChoice.series),
            style: TextButton.styleFrom(foregroundColor: _dangerColor),
            child: Text('ลบทุกวัน (${series.length})'),
          ),
        ],
      ),
    );
    return choice ?? _DeleteChoice.cancel;
  }

  Future<void> _deleteEvent(ScheduleEvent e) async {
    await _repo.delete(e.id);
    _syncReminders();
    _toast('ลบ “${e.title}” แล้ว');
  }

  void _selectDate(DateTime date, {_ScheduleView? view}) => setState(() {
    _selectedDate = CalendarUtils.dateOnly(date);
    _visibleMonth = DateTime(date.year, date.month);
    if (view != null) _view = view;
  });

  /// เลือกวันในสัปดาห์เดียวกับวันที่เลือกอยู่ (1 = จันทร์ ... 7 = อาทิตย์)
  DateTime _dateOfWeekday(int weekday) => CalendarUtils.addDays(CalendarUtils.startOfWeek(_selectedDate), weekday - 1);

  void _selectDay(int weekday) => _selectDate(_dateOfWeekday(weekday), view: _ScheduleView.day);

  void _goToday() => _selectDate(DateTime.now());

  /// ฟอร์มเดียวใช้ทั้งเพิ่มใหม่ (existing = null) และแก้ไขกิจกรรมเดิม
  ///
  /// เพิ่มใหม่: เลือกได้หลายวัน → สร้างเป็นรายการแยกของแต่ละวันในชุดเดียวกัน
  /// แก้ไข: ย้ายวัน / คัดลอกไปวันอื่นเพิ่ม / นำการแก้ไขไปใช้กับทุกวันในชุด
  /// ทั้งสองแบบสลับเป็น "เฉพาะวันที่" ได้ = นัดหมายครั้งเดียว ไม่ซ้ำทุกสัปดาห์
  Future<void> _openEventForm(BuildContext context, {ScheduleEvent? existing}) async {
    final titleController = TextEditingController(text: existing?.title);
    final subtitleController = TextEditingController(text: existing?.subtitle);
    LifeCategory selectedCategory = existing?.category ?? LifeCategory.work;
    int selectedWeekday = existing?.weekday ?? _selectedWeekday;
    TimeOfDay selectedTime = existing != null ? _parseTime(existing.time) : TimeOfDay.now();

    // เพิ่มจากมุมมองเดือน (แตะวันที่ในปฏิทินมาแล้ว) ส่วนใหญ่คือนัดหมายเฉพาะวันนั้น
    var oneOff = existing?.isOneOff ?? _view == _ScheduleView.month;
    var selectedDate = existing?.date ?? _selectedDate;

    // เพิ่มใหม่: วันที่เลือก (หลายวันได้) / แก้ไข: วันที่จะคัดลอกไปเพิ่ม
    final newDays = <int>{_selectedWeekday};
    final copyDays = <int>{};

    final series = existing == null ? const <ScheduleEvent>[] : _repo.seriesOf(existing);
    final siblingDays = series.where((e) => e.id != existing?.id).map((e) => e.weekday).toSet();
    var applyToSeries = false;

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
                  if (series.length > 1) {
                    final choice = await _confirmDeleteSeries(sheetCtx, existing, series);
                    if (choice == _DeleteChoice.cancel) return;
                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    if (choice == _DeleteChoice.single) {
                      await _deleteEvent(existing);
                    } else {
                      final count = await _repo.deleteSeries(existing);
                      _syncReminders();
                      _toast('ลบ “${existing.title}” ทั้ง $count วันแล้ว');
                    }
                    return;
                  }
                  if (!await _confirmDelete(sheetCtx, existing)) return;
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                  await _deleteEvent(existing);
                },
                style: TextButton.styleFrom(foregroundColor: _dangerColor, padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: const Text('ลบกิจกรรมนี้', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthField(label: 'ชื่อกิจกรรม', hint: 'เช่น วิ่งตอนเช้า / เข้านอน', controller: titleController),
            const SizedBox(height: 14),
            LabeledDropdown<LifeCategory>(
              label: 'หมวดหมู่',
              value: selectedCategory,
              options: LifeCategory.values,
              display: (c) => c.label,
              onChanged: (v) => setState(() => selectedCategory = v!),
            ),
            const SizedBox(height: 14),
            _RepeatToggle(
              oneOff: oneOff,
              onChanged: (v) => setState(() {
                oneOff = v;
                // เปลี่ยนนัดเฉพาะวันเป็นประจำสัปดาห์ → เริ่มจากวันในสัปดาห์ของวันที่เดิม
                if (!v) {
                  selectedWeekday = selectedDate.weekday;
                  newDays
                    ..clear()
                    ..add(selectedDate.weekday);
                }
              }),
            ),
            const SizedBox(height: 14),
            if (oneOff) ...[
              const _FieldLabel('วันที่'),
              const SizedBox(height: 7),
              _PickerBox(
                key: const ValueKey('event-date-field'),
                text: 'วัน${_weekdayFullLabels[selectedDate.weekday - 1]}ที่ ${CalendarUtils.thaiDate(selectedDate)}',
                icon: Icons.event_rounded,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => selectedDate = CalendarUtils.dateOnly(picked));
                },
              ),
              const SizedBox(height: 6),
              const _Hint('นัดหมายครั้งเดียว ไม่ซ้ำทุกสัปดาห์ — เช่น นัดหมอ หรือนัดลูกค้าวันที่ 25'),
            ] else if (existing == null) ...[
              const _FieldLabel('วัน (เลือกได้หลายวัน)'),
              const SizedBox(height: 8),
              _WeekdayPicker(
                selected: newDays,
                // ต้องเหลืออย่างน้อย 1 วันเสมอ
                onChanged: (days) => setState(() {
                  if (days.isEmpty) return;
                  newDays
                    ..clear()
                    ..addAll(days);
                }),
              ),
              const SizedBox(height: 6),
              const _Hint('เลือกหลายวัน = สร้างเป็นกิจกรรมแยกของแต่ละวัน แก้ไขทีละวันหรือทั้งชุดได้ภายหลัง'),
            ] else ...[
              LabeledDropdown<int>(
                label: 'วัน',
                value: selectedWeekday,
                options: const [1, 2, 3, 4, 5, 6, 7],
                display: (d) => 'วัน${_weekdayFullLabels[d - 1]}',
                onChanged: (v) => setState(() {
                  selectedWeekday = v!;
                  copyDays.remove(selectedWeekday);
                }),
              ),
            ],
            const SizedBox(height: 14),
            const _FieldLabel('เวลา'),
            const SizedBox(height: 7),
            _PickerBox(
              text: _formatTime(selectedTime),
              onTap: () async {
                final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
                if (picked != null) setState(() => selectedTime = picked);
              },
            ),
            const SizedBox(height: 14),
            AuthField(label: 'รายละเอียด (ไม่บังคับ)', hint: 'เช่น สถานที่ / ระยะเวลา', controller: subtitleController),
            if (existing != null && !oneOff) ...[
              if (siblingDays.isNotEmpty && !existing.isOneOff) ...[
                const SizedBox(height: 14),
                _SeriesSwitch(
                  value: applyToSeries,
                  days: series.map((e) => e.weekday),
                  onChanged: (v) => setState(() => applyToSeries = v),
                ),
              ],
              const SizedBox(height: 16),
              const _FieldLabel('คัดลอกไปวันอื่นด้วย (ไม่บังคับ)'),
              const SizedBox(height: 8),
              _WeekdayPicker(
                selected: copyDays,
                // วันของรายการนี้เอง และวันที่มีกิจกรรมชุดนี้อยู่แล้ว เลือกซ้ำไม่ได้
                disabled: {selectedWeekday, ...siblingDays},
                onChanged: (days) => setState(() {
                  copyDays
                    ..clear()
                    ..addAll(days);
                }),
              ),
              const SizedBox(height: 6),
              _Hint(
                siblingDays.isEmpty ? 'เช่น วิ่งตอนเช้าทุกวัน — สำเนาแต่ละวันแก้ไขแยกกันได้' : 'วันที่จางคือวันที่มีกิจกรรมนี้อยู่แล้ว',
              ),
            ],
          ],
        ),
      ),
      onSubmit: () async {
        final title = titleController.text.trim();
        if (title.isEmpty) return;
        final subtitle = subtitleController.text.trim().isEmpty ? null : subtitleController.text.trim();

        DateTime jumpTo;
        if (oneOff) {
          // แปลงจากกิจกรรมในชุดประจำสัปดาห์ก็หลุดจากชุดไปเลย (ไม่มี seriesId) — วันอื่นในชุดยังอยู่ครบ
          await _repo.put(ScheduleEvent.oneOff(
            id: existing?.id ?? newId(),
            time: _formatTime(selectedTime),
            date: selectedDate,
            title: title,
            subtitle: subtitle,
            category: selectedCategory,
          ));
          jumpTo = selectedDate;
        } else if (existing == null) {
          final days = newDays.toList()..sort();
          jumpTo = _dateOfWeekday(days.first);
          final base = ScheduleEvent(
            id: newId(),
            time: _formatTime(selectedTime),
            weekday: days.first,
            title: title,
            subtitle: subtitle,
            category: selectedCategory,
          );
          await _repo.put(base);
          final copies = await _repo.copyToWeekdays(base, days.skip(1));
          if (days.length > 1) _toast('เพิ่ม “$title” ${copies + 1} วัน (${_weekdayList(days)})');
        } else {
          jumpTo = _dateOfWeekday(selectedWeekday);
          final updated = ScheduleEvent(
            id: existing.id,
            time: _formatTime(selectedTime),
            weekday: selectedWeekday,
            title: title,
            subtitle: subtitle,
            category: selectedCategory,
            seriesId: existing.isOneOff ? null : existing.seriesId,
          );
          await _repo.put(updated);
          final updatedCount = applyToSeries && !existing.isOneOff ? await _repo.updateSeries(updated) : 1;
          final copies = copyDays.isEmpty ? 0 : await _repo.copyToWeekdays(updated, copyDays);
          if (updatedCount > 1 || copies > 0) {
            _toast([if (updatedCount > 1) 'แก้ไขทั้งชุด $updatedCount วัน', if (copies > 0) 'คัดลอกไปอีก $copies วัน'].join(' • '));
          }
        }

        _syncReminders();
        // เด้งไปวันที่เพิ่งบันทึก เพื่อให้เห็นกิจกรรมทันที (กรณีแก้ไขแล้วย้ายวันด้วย)
        if (mounted) {
          _selectDate(jumpTo, view: _view == _ScheduleView.week ? _ScheduleView.day : null);
        }
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  /// คัดลอกกิจกรรมทั้งหมดของวันหนึ่งไปวันอื่น (เช่น ตารางวันจันทร์ → อังคาร–ศุกร์)
  Future<void> _openCopyDaySheet(BuildContext context, int fromWeekday) async {
    final events = _repo.getByWeekday(fromWeekday);
    if (events.isEmpty) return;
    final targets = <int>{};

    await showAppFormSheet(
      context: context,
      title: 'คัดลอกกิจกรรมทั้งวัน${_weekdayFullLabels[fromWeekday - 1]}',
      submitLabel: 'คัดลอก',
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hint('${events.length} กิจกรรม: ${events.map((e) => '${e.time} ${e.title}').join(' • ')}'),
            const SizedBox(height: 16),
            const _FieldLabel('คัดลอกไปวัน'),
            const SizedBox(height: 8),
            _WeekdayPicker(
              selected: targets,
              disabled: {fromWeekday},
              onChanged: (days) => setState(() {
                targets
                  ..clear()
                  ..addAll(days);
              }),
            ),
            const SizedBox(height: 6),
            const _Hint('คัดลอกเฉพาะกิจกรรมประจำสัปดาห์ (นัดหมายเฉพาะวันที่ไม่ถูกคัดลอก) • กิจกรรมที่มีชื่อและเวลาเดียวกันอยู่แล้วในวันปลายทางจะถูกข้าม'),
          ],
        ),
      ),
      onSubmit: () async {
        if (targets.isEmpty) return;
        final created = await _repo.copyDay(fromWeekday, targets);
        _syncReminders();
        if (context.mounted) Navigator.of(context).pop();
        _toast(created == 0 ? 'วันที่เลือกมีกิจกรรมเหล่านี้ครบอยู่แล้ว' : 'คัดลอก $created กิจกรรมไปวัน ${_weekdayList(targets)} แล้ว');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = CalendarUtils.startOfWeek(_selectedDate);
    final showWeekStrip = _view == _ScheduleView.day || _view == _ScheduleView.week;

    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: _repo.listenable(),
        builder: (context, _, _) {
          final all = _repo.getAll();
          List<ScheduleEvent> eventsOn(DateTime date) => ScheduleRepository.eventsOn(all, date);

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
                    const SizedBox(height: 12),
                    _ViewToggle(view: _view, onChanged: (v) => setState(() => _view = v)),
                    if (showWeekStrip) ...[
                      const SizedBox(height: 8),
                      _PeriodNav(
                        label: _weekRangeLabel(weekStart),
                        onPrev: () => _selectDate(CalendarUtils.addDays(_selectedDate, -7)),
                        onNext: () => _selectDate(CalendarUtils.addDays(_selectedDate, 7)),
                        onToday: CalendarUtils.isSameDay(weekStart, CalendarUtils.startOfWeek(now)) ? null : _goToday,
                      ),
                      const SizedBox(height: 4),
                      _WeekStrip(
                        weekStart: weekStart,
                        now: now,
                        selectedDate: _view == _ScheduleView.day ? _selectedDate : null,
                        eventsOn: eventsOn,
                        onTap: _selectDay,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: _buildBody(context, eventsOn, weekStart, now)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, _EventsOn eventsOn, DateTime weekStart, DateTime now) {
    switch (_view) {
      case _ScheduleView.day:
        final events = eventsOn(_selectedDate);
        return Column(
          children: [
            _DayHeader(
              date: _selectedDate,
              count: events.length,
              // คัดลอกทั้งวันใช้ได้กับกิจกรรมประจำสัปดาห์เท่านั้น
              onCopyDay: events.any((e) => !e.isOneOff) ? () => _openCopyDaySheet(context, _selectedWeekday) : null,
            ),
            Expanded(
              child: _DayTimeline(
                events: events,
                weekday: _selectedWeekday,
                onEventTap: (e) => _openEventForm(context, existing: e),
                confirmDelete: (e) => _confirmDelete(context, e),
                onDelete: _deleteEvent,
              ),
            ),
          ],
        );
      case _ScheduleView.week:
        return _WeekGrid(
          eventsOn: eventsOn,
          weekStart: weekStart,
          now: now,
          onDayTap: _selectDay,
          onEventTap: (e) => _openEventForm(context, existing: e),
        );
      case _ScheduleView.month:
        return _MonthView(
          month: _visibleMonth,
          selectedDate: _selectedDate,
          now: now,
          eventsOn: eventsOn,
          onPrev: () => setState(() => _visibleMonth = CalendarUtils.addMonths(_visibleMonth, -1)),
          onNext: () => setState(() => _visibleMonth = CalendarUtils.addMonths(_visibleMonth, 1)),
          onToday: _goToday,
          onTitleTap: () => setState(() => _view = _ScheduleView.year),
          onDateTap: (d) => _selectDate(d),
          onOpenDay: () => setState(() => _view = _ScheduleView.day),
          onEventTap: (e) => _openEventForm(context, existing: e),
          onCopyDay: () => _openCopyDaySheet(context, _selectedWeekday),
        );
      case _ScheduleView.year:
        return _YearView(
          year: _visibleMonth.year,
          now: now,
          eventsOn: eventsOn,
          onPrev: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year - 1, _visibleMonth.month)),
          onNext: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year + 1, _visibleMonth.month)),
          onToday: now.year == _visibleMonth.year ? null : _goToday,
          onMonthTap: (m) => setState(() {
            _visibleMonth = m;
            _view = _ScheduleView.month;
          }),
        );
    }
  }

  /// "14–20 ก.ย. 2569" หรือ "28 ก.ย. – 4 ต.ค. 2569" เมื่อสัปดาห์คร่อมเดือน
  static String _weekRangeLabel(DateTime start) {
    final end = CalendarUtils.addDays(start, 6);
    final endLabel = '${end.day} ${CalendarUtils.monthShort[end.month - 1]} ${end.year + 543}';
    if (start.month == end.month) return '${start.day}–$endLabel';
    final startYear = start.year == end.year ? '' : ' ${start.year + 543}';
    return '${start.day} ${CalendarUtils.monthShort[start.month - 1]}$startYear – $endLabel';
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textFaint));
}

/// ช่องกดเลือกค่า (เวลา/วันที่) หน้าตาเดียวกับช่องกรอกข้อความ
class _PickerBox extends StatelessWidget {
  const _PickerBox({super.key, required this.text, required this.onTap, this.icon});

  final String text;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.text))),
            if (icon != null) Icon(icon, size: 18, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

/// สลับ "ทุกสัปดาห์" (ตารางประจำ) กับ "เฉพาะวันที่" (นัดหมายครั้งเดียว)
class _RepeatToggle extends StatelessWidget {
  const _RepeatToggle({required this.oneOff, required this.onChanged});

  final bool oneOff;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, IconData icon, bool value) {
      final selected = oneOff == value;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('repeat-${value ? 'one-off' : 'weekly'}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textFaint),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? AppColors.text : AppColors.textFaint),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          option('ทุกสัปดาห์', Icons.repeat_rounded, false),
          option('เฉพาะวันที่', Icons.event_rounded, true),
        ],
      ),
    );
  }
}

/// ป้ายเล็ก ๆ บอกว่าเป็นนัดหมายเฉพาะวันที่ ไม่ใช่กิจกรรมประจำสัปดาห์
class _OneOffTag extends StatelessWidget {
  const _OneOffTag();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_rounded, size: 13, color: AppColors.textMuted),
          SizedBox(width: 4),
          Text('นัดหมายเฉพาะวันนี้', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// เลือกวันในสัปดาห์ได้หลายวัน พร้อมปุ่มลัด ทุกวัน / จ–ศ / ส–อา
class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged, this.disabled = const {}});

  final Set<int> selected;
  final Set<int> disabled;
  final ValueChanged<Set<int>> onChanged;

  void _toggle(int day) {
    final next = {...selected};
    if (!next.remove(day)) next.add(day);
    onChanged(next);
  }

  void _preset(Iterable<int> days) => onChanged(days.where((d) => !disabled.contains(d)).toSet());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(7, (i) {
            final day = i + 1;
            final isDisabled = disabled.contains(day);
            final isSelected = selected.contains(day) && !isDisabled;
            return Expanded(
              child: GestureDetector(
                key: ValueKey('weekday-chip-$day'),
                behavior: HitTestBehavior.opaque,
                onTap: isDisabled ? null : () => _toggle(day),
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : (isDisabled ? AppColors.surface2 : AppColors.surface),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 1.5),
                  ),
                  child: Text(
                    _weekdayLabels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : (isDisabled ? AppColors.border : AppColors.text),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _PresetChip(label: 'ทุกวัน', onTap: () => _preset(const [1, 2, 3, 4, 5, 6, 7])),
            _PresetChip(label: 'จ–ศ', onTap: () => _preset(const [1, 2, 3, 4, 5])),
            _PresetChip(label: 'ส–อา', onTap: () => _preset(const [6, 7])),
          ],
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(999)),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

/// สวิตช์ "แก้ไขทุกวันในชุดนี้" — โชว์เฉพาะกิจกรรมที่มีสำเนาอยู่วันอื่น
class _SeriesSwitch extends StatelessWidget {
  const _SeriesSwitch({required this.value, required this.days, required this.onChanged});

  final bool value;
  final Iterable<int> days;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ใช้การแก้ไขกับทุกวันในชุดนี้',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  'กิจกรรมนี้มีอยู่วัน ${_weekdayList(days)} — ปิดไว้ = แก้เฉพาะวันนี้',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
          Switch(value: value, activeTrackColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// ปุ่มสลับมุมมอง วัน / สัปดาห์ / เดือน / ปี
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onChanged});

  final _ScheduleView view;
  final ValueChanged<_ScheduleView> onChanged;

  static const _labels = {_ScheduleView.day: 'วัน', _ScheduleView.week: 'สัปดาห์', _ScheduleView.month: 'เดือน', _ScheduleView.year: 'ปี'};

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (final entry in _labels.entries)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(entry.key),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entry.key == view ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: entry.key == view ? AppColors.text : AppColors.textFaint,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// แถบ "‹ ช่วงเวลา › [วันนี้]" ใช้ร่วมกันทั้งสัปดาห์ เดือน และปี
class _PeriodNav extends StatelessWidget {
  const _PeriodNav({required this.label, required this.onPrev, required this.onNext, this.onToday, this.onLabelTap});

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  /// null = อยู่ช่วงปัจจุบันแล้ว ไม่ต้องโชว์ปุ่ม "วันนี้"
  final VoidCallback? onToday;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavArrow(icon: Icons.chevron_left_rounded, tooltip: 'ก่อนหน้า', onTap: onPrev),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLabelTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                  ),
                ),
                if (onLabelTap != null) const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textFaint),
              ],
            ),
          ),
        ),
        if (onToday != null)
          GestureDetector(
            onTap: onToday,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.primary, width: 1.2),
              ),
              child: const Text(
                'วันนี้',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ),
        _NavArrow(icon: Icons.chevron_right_rounded, tooltip: 'ถัดไป', onTap: onNext),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 22, color: AppColors.textMuted)),
      ),
    );
  }
}

/// แถบ 7 วันของสัปดาห์ที่เลือก
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.weekStart, required this.now, required this.selectedDate, required this.eventsOn, required this.onTap});

  final DateTime weekStart;
  final DateTime now;

  /// null = ไม่ไฮไลต์วันใด (มุมมองสัปดาห์)
  final DateTime? selectedDate;
  final _EventsOn eventsOn;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final date = CalendarUtils.addDays(weekStart, i);
        final selected = selectedDate != null && CalendarUtils.isSameDay(date, selectedDate!);
        final isToday = CalendarUtils.isSameDay(date, now);
        final hasEvents = eventsOn(date).isNotEmpty;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i + 1),
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
                  Text(
                    _weekdayLabels[i],
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textFaint),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textFaint),
                  ),
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
    );
  }
}

/// หัวมุมมองรายวัน: วันที่ + จำนวนกิจกรรม + ปุ่มคัดลอกทั้งวัน
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.count, required this.onCopyDay});

  final DateTime date;
  final int count;
  final VoidCallback? onCopyDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${CalendarUtils.thaiDate(date)} • $count กิจกรรม',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            ),
          ),
          if (onCopyDay != null)
            TextButton.icon(
              onPressed: onCopyDay,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: const Text('คัดลอกทั้งวัน', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// ตาราง 7 คอลัมน์ (จันทร์–อาทิตย์) เลื่อนแนวนอนได้ แต่ละคอลัมน์เรียงกิจกรรมตามเวลา
class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.eventsOn, required this.weekStart, required this.now, required this.onDayTap, required this.onEventTap});

  final _EventsOn eventsOn;
  final DateTime weekStart;
  final DateTime now;
  final ValueChanged<int> onDayTap;
  final ValueChanged<ScheduleEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    // เลื่อนได้ทั้งสองแนว — วันที่มีกิจกรรมเยอะ (เช่น คัดลอกไปทุกวัน) คอลัมน์จะยาวเกินจอ
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(7, (i) {
            final date = CalendarUtils.addDays(weekStart, i);
            final events = eventsOn(date);
            final isToday = CalendarUtils.isSameDay(date, now);
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
                            child: Text(
                              _weekdayFullLabels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isToday ? AppColors.primary : AppColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${date.day}/${date.month}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textFaint),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  if (events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'ว่าง',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
                      ),
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
                                    Row(
                                      children: [
                                        Text(
                                          e.time,
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                                        ),
                                        if (e.isOneOff) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.event_rounded, size: 11, color: AppColors.textMuted),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      e.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.25),
                                    ),
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
      ),
    );
  }
}

/// ปฏิทินรายเดือน — แต่ละช่องมีจุดสีตามหมวดของกิจกรรมวันนั้น แตะเพื่อดูรายการด้านล่าง
///
/// กิจกรรมประจำสัปดาห์ขึ้นทุกสัปดาห์ ส่วนนัดหมายเฉพาะวันที่ขึ้นแค่วันนั้น
class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.selectedDate,
    required this.now,
    required this.eventsOn,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onTitleTap,
    required this.onDateTap,
    required this.onOpenDay,
    required this.onEventTap,
    required this.onCopyDay,
  });

  final DateTime month;
  final DateTime selectedDate;
  final DateTime now;
  final _EventsOn eventsOn;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onTitleTap;
  final ValueChanged<DateTime> onDateTap;
  final VoidCallback onOpenDay;
  final ValueChanged<ScheduleEvent> onEventTap;
  final VoidCallback onCopyDay;

  @override
  Widget build(BuildContext context) {
    final days = CalendarUtils.monthGrid(month.year, month.month);
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final events = eventsOn(selectedDate);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _PeriodNav(
          label: CalendarUtils.thaiMonthYear(month),
          onPrev: onPrev,
          onNext: onNext,
          onToday: isCurrentMonth && CalendarUtils.isSameDay(selectedDate, now) ? null : onToday,
          onLabelTap: onTitleTap,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Text(
                        _weekdayLabels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: i >= 5 ? AppColors.nutrition : AppColors.textFaint,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (var row = 0; row < days.length ~/ 7; row++)
                Row(
                  children: [
                    for (final date in days.skip(row * 7).take(7))
                      Expanded(
                        child: _MonthCell(
                          date: date,
                          inMonth: date.month == month.month,
                          isToday: CalendarUtils.isSameDay(date, now),
                          isSelected: CalendarUtils.isSameDay(date, selectedDate),
                          events: eventsOn(date),
                          onTap: () => onDateTap(date),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'วัน${_weekdayFullLabels[selectedDate.weekday - 1]}ที่ ${CalendarUtils.thaiDate(selectedDate)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
            if (events.any((e) => !e.isOneOff))
              IconButton(
                tooltip: 'คัดลอกทั้งวัน',
                onPressed: onCopyDay,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_all_rounded, size: 20, color: AppColors.primary),
              ),
            TextButton(
              onPressed: onOpenDay,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary, visualDensity: VisualDensity.compact),
              child: const Text('ดูรายวัน', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'ไม่มีกิจกรรมในวันนี้ — กดปุ่ม + เพื่อเพิ่ม',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
            ),
          )
        else
          for (final e in events) _EventRow(event: e, onTap: () => onEventTap(e)),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<ScheduleEvent> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // จุดสีไม่ซ้ำหมวด เรียงตามเวลาของกิจกรรมแรกในหมวดนั้น — ไม่เกิน 4 จุดให้พอดีช่อง
    final categories = <LifeCategory>[];
    for (final e in events) {
      if (!categories.contains(e.category)) categories.add(e.category);
    }
    final textColor = isSelected ? Colors.white : (inMonth ? AppColors.text : AppColors.border);

    return GestureDetector(
      key: ValueKey('month-cell-${date.year}-${date.month}-${date.day}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: !isSelected && isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(fontSize: 13, fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final c in categories.take(4))
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : (inMonth ? c.color : c.color.withValues(alpha: 0.35)),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// แถวกิจกรรมแบบย่อ ใช้ใต้ปฏิทินรายเดือน
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onTap});

  final ScheduleEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: event.category.softColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: event.category.color, width: 3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                event.time,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  if (event.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(event.subtitle!, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                  if (event.isOneOff) const _OneOffTag(),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 16, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

/// ปฏิทินทั้งปี 12 เดือน แตะเดือนเพื่อเปิดมุมมองรายเดือน
class _YearView extends StatelessWidget {
  const _YearView({
    required this.year,
    required this.now,
    required this.eventsOn,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onMonthTap,
  });

  final int year;
  final DateTime now;
  final _EventsOn eventsOn;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onToday;
  final ValueChanged<DateTime> onMonthTap;

  /// จำนวนกิจกรรมทั้งเดือน = ผลรวมกิจกรรมของทุกวันในเดือน (ประจำสัปดาห์ + นัดเฉพาะวัน)
  int _monthEventCount(int month) {
    var total = 0;
    for (var d = 1; d <= CalendarUtils.daysInMonth(year, month); d++) {
      total += eventsOn(DateTime(year, month, d)).length;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _PeriodNav(label: 'ปี ${year + 543} ($year)', onPrev: onPrev, onNext: onNext, onToday: onToday),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            const gap = 10.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var m = 1; m <= 12; m++)
                  SizedBox(
                    width: width,
                    child: _MiniMonth(
                      year: year,
                      month: m,
                      now: now,
                      eventCount: _monthEventCount(m),
                      onTap: () => onMonthTap(DateTime(year, m)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({required this.year, required this.month, required this.now, required this.eventCount, required this.onTap});

  final int year;
  final int month;
  final DateTime now;
  final int eventCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = CalendarUtils.monthGrid(year, month);
    final isCurrent = now.year == year && now.month == month;

    return GestureDetector(
      key: ValueKey('mini-month-$year-$month'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border, width: isCurrent ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    CalendarUtils.monthFull[month - 1],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isCurrent ? AppColors.primary : AppColors.text),
                  ),
                ),
                if (eventCount > 0)
                  Text(
                    '$eventCount',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textFaint),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var row = 0; row < days.length ~/ 7; row++)
              Row(
                children: [
                  for (final date in days.skip(row * 7).take(7))
                    Expanded(
                      child: Container(
                        height: 17,
                        alignment: Alignment.center,
                        decoration: CalendarUtils.isSameDay(date, now)
                            ? const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)
                            : null,
                        child: date.month == month
                            ? Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: CalendarUtils.isSameDay(date, now) ? Colors.white : AppColors.textMuted,
                                ),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
          ],
        ),
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
        child: Text(
          'ยังไม่มีกิจกรรมวัน${_weekdayFullLabels[weekday - 1]} — กดปุ่ม + เพื่อเพิ่ม',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  child: Text(
                    e.time,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textFaint),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: e.category.color, shape: BoxShape.circle),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(width: 2, color: AppColors.border, margin: const EdgeInsets.symmetric(vertical: 2)),
                      ),
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
                                if (e.isOneOff) const _OneOffTag(),
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
