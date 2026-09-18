import 'package:flutter/material.dart';

import 'dart:async';

import '../data/bedtime_reminder.dart';
import '../data/insights.dart';
import '../data/notifications.dart';
import '../data/repositories/schedule_repository.dart';
import '../data/repositories/goal_settings_repository.dart';
import '../data/repositories/sleep_repository.dart';
import '../data/repositories/meal_repository.dart';
import '../data/sleep_history.dart';
import '../data/sleep_nutrition_insights.dart';
import '../models/goal_settings.dart';
import '../models/life_category.dart';
import '../models/sleep_entry.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/progress_track.dart';
import '../widgets/section_heading.dart';

/// โมดูลคุณภาพการนอน — บันทึกเวลาเข้านอน/ตื่น คุณภาพที่รู้สึก จำนวนครั้งที่ตื่น
/// กลางดึก และปัจจัยรบกวน แล้วสรุปเป็นคะแนนกับคำแนะนำจาก 7 คืนล่าสุด
class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  static const _category = LifeCategory.sleep;
  static const _dangerColor = Color(0xFFD64545);

  /// จำนวนคืนที่ใช้สรุปสถิติและกราฟรายสัปดาห์
  static const _windowNights = 7;

  /// จำนวนคืนของกราฟย้อนหลังรายเดือน
  static const _monthNights = 30;

  static const _thaiWeekdayShort = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
  static const _thaiMonthShort = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parseTime(String value) {
    final minutes = SleepEntry.minutesOf(value) ?? 0;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  /// "7 ชม. 20 นาที" — ตัดส่วนนาทีทิ้งเมื่อลงตัวพอดี
  static String _duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m นาที';
    return m == 0 ? '$h ชม.' : '$h ชม. $m นาที';
  }

  static String _nightLabel(SleepEntry entry) {
    final night = entry.nightDate;
    return 'คืนวัน${_thaiWeekdayShort[night.weekday - 1]} ${night.day} ${_thaiMonthShort[night.month - 1]}';
  }

  /// สีของแถบ/ชิปตามคะแนนคืนนั้น เพื่อให้เห็นคืนที่แย่ได้ทันทีโดยไม่ต้องอ่านตัวเลข
  static Color _scoreColor(int score) {
    if (score >= 80) return AppColors.exercise;
    if (score >= 60) return _category.color;
    if (score >= 40) return AppColors.crm;
    return _dangerColor;
  }

  Future<void> _openForm(
    BuildContext context,
    SleepRepository repo, {
    SleepEntry? existing,
  }) async {
    var date = existing?.date ?? DateTime.now();
    var bedTime = _parseTime(existing?.bedTime ?? '23:00');
    var wakeTime = _parseTime(existing?.wakeTime ?? '07:00');
    var quality = existing?.quality ?? SleepQuality.good;
    final factors = {...?existing?.factors};
    final awakeningsController = TextEditingController(text: '${existing?.awakenings ?? 0}');
    final noteController = TextEditingController(text: existing?.note ?? '');

    /// ระยะเวลาที่จะได้ถ้ากดบันทึกตอนนี้ — โชว์สดในฟอร์มให้เห็นว่าไม่ได้กรอกสลับกัน
    int previewMinutes() =>
        (wakeTime.hour * 60 + wakeTime.minute - bedTime.hour * 60 - bedTime.minute + 1440) % 1440;

    await showAppFormSheet(
      context: context,
      title: existing == null ? 'บันทึกการนอน' : 'แก้ไขการนอน',
      submitLabel: 'บันทึก',
      bodyBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PickerField(
              label: 'วันที่ตื่นนอน',
              value: '${date.day} ${_thaiMonthShort[date.month - 1]} ${date.year + 543}',
              icon: Icons.calendar_today_rounded,
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: date,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setSheetState(() => date = picked);
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: 'เข้านอน',
                    value: _formatTime(bedTime),
                    icon: Icons.bedtime_outlined,
                    onTap: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: bedTime);
                      if (picked != null) setSheetState(() => bedTime = picked);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerField(
                    label: 'ตื่นนอน',
                    value: _formatTime(wakeTime),
                    icon: Icons.wb_sunny_outlined,
                    onTap: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: wakeTime);
                      if (picked != null) setSheetState(() => wakeTime = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('ได้นอน ${_duration(previewMinutes())}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _category.color)),
            const SizedBox(height: 14),
            LabeledDropdown<SleepQuality>(
              label: 'คุณภาพการนอนที่รู้สึก',
              value: quality,
              options: SleepQuality.values,
              display: (q) => q.label,
              onChanged: (v) => setSheetState(() => quality = v!),
            ),
            const SizedBox(height: 14),
            AuthField(
              label: 'ตื่นกลางดึก (ครั้ง)',
              hint: '0',
              controller: awakeningsController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text('ปัจจัยรบกวน (เลือกได้หลายข้อ)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final factor in SleepFactor.values)
                  _FactorChip(
                    label: factor.label,
                    selected: factors.contains(factor),
                    onTap: () => setSheetState(() {
                      factors.contains(factor) ? factors.remove(factor) : factors.add(factor);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AuthField(label: 'บันทึกเพิ่มเติม', hint: 'เช่น ฝันร้าย / ห้องร้อน', controller: noteController),
          ],
        ),
      ),
      onSubmit: () async {
        final note = noteController.text.trim();
        await repo.put(SleepEntry(
          date: date,
          bedTime: _formatTime(bedTime),
          wakeTime: _formatTime(wakeTime),
          quality: quality,
          awakenings: int.tryParse(awakeningsController.text.trim())?.clamp(0, 99) ?? 0,
          factors: factors.toList(),
          note: note.isEmpty ? null : note,
        ));
        if (context.mounted) Navigator.of(context).pop();
      },
      footerBuilder: existing == null
          ? null
          : (ctx) => Center(
                child: TextButton(
                  onPressed: () async {
                    final confirmed = await _confirmDelete(ctx, existing);
                    if (!confirmed) return;
                    await repo.delete(existing.id);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('ลบบันทึกคืนนี้',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dangerColor)),
                ),
              ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, SleepEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบบันทึกการนอน?'),
        content: Text('${_nightLabel(entry)} (${_duration(entry.durationMinutes)}) จะถูกลบออกจากสถิติ'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ลบ', style: TextStyle(color: _dangerColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// คำแนะนำที่อ้างอิงข้อมูลจริงของผู้ใช้ ไม่ใช่ข้อความคงที่
  static List<String> tipsFor(SleepStats stats, GoalSettings goals) {
    if (stats.isEmpty) return const [];
    final tips = <String>[];

    final shortfall = goals.sleepTargetMinutes - stats.averageMinutes;
    if (shortfall >= 30) {
      tips.add('เฉลี่ยนอนน้อยกว่าเป้า ${_duration(shortfall.round())} ต่อคืน — '
          'ลองเข้านอนเร็วขึ้นวันละ 15 นาทีจนกว่าจะเข้าที่');
    } else if (stats.averageMinutes - goals.sleepTargetMinutes >= 60) {
      tips.add('นอนเกินเป้าเฉลี่ย ${_duration((stats.averageMinutes - goals.sleepTargetMinutes).round())} '
          'ต่อคืน — ถ้ายังตื่นมาไม่สดชื่น ลองดูคุณภาพการนอนมากกว่าจำนวนชั่วโมง');
    }

    if (stats.averageAwakenings >= 1.5) {
      tips.add('ตื่นกลางดึกเฉลี่ย ${stats.averageAwakenings.toStringAsFixed(1)} ครั้ง/คืน — '
          'ลดน้ำก่อนนอน 1 ชั่วโมง และทำให้ห้องมืด-เย็นขึ้น');
    }

    if (stats.bedtimeConsistency < 0.6 && stats.nightCount >= 3) {
      tips.add('เวลาเข้านอนเหวี่ยงมาก (สม่ำเสมอ ${(stats.bedtimeConsistency * 100).round()}%) — '
          'นาฬิกาชีวภาพชอบเวลาเดิมมากกว่าจำนวนชั่วโมงที่มากขึ้น');
    }

    for (final factor in stats.commonFactors.take(2)) {
      tips.add('${factor.label}: ${factor.advice}');
    }

    return tips;
  }

  @override
  Widget build(BuildContext context) {
    final repo = SleepRepository();
    final goalsRepo = GoalSettingsRepository();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.listenable(), goalsRepo.listenable()]),
          builder: (context, _) {
            final goals = goalsRepo.get();
            final lastNight = repo.getLastNight();
            final recent = repo.getRecent(days: _windowNights);
            final stats = SleepStats.of(recent);
            final history = repo.getAllSorted();
            final tips = tipsFor(stats, goals);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Row(
                  children: [
                    BackButtonCircle(),
                    SizedBox(width: 12),
                    Text('คุณภาพการนอน',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  ],
                ),
                const SizedBox(height: 16),
                _LastNightCard(
                  entry: lastNight,
                  targetMinutes: goals.sleepTargetMinutes,
                  onRecord: () => _openForm(context, repo),
                ),
                const SizedBox(height: 20),

                const SectionHeading(title: '7 คืนล่าสุด'),
                const SizedBox(height: 12),
                AppCard(
                  child: recent.isEmpty
                      ? const Text('ยังไม่มีบันทึกการนอนในสัปดาห์นี้',
                          style: TextStyle(fontSize: 12.5, color: AppColors.textFaint))
                      : _WeekChart(nights: recent, targetMinutes: goals.sleepTargetMinutes),
                ),
                const SizedBox(height: 16),

                _BedtimeReminderCard(nights: recent, goals: goals),
                const SizedBox(height: 16),

                _MonthHistoryCard(
                  history: SleepHistory.of(repo, days: _monthNights),
                  targetMinutes: goals.sleepTargetMinutes,
                ),
                const SizedBox(height: 16),

                _FoodComparisonCard(
                  nights: SleepHistory.of(repo, days: _monthNights).loggedNights,
                  targetMinutes: goals.sleepTargetMinutes,
                ),
                const SizedBox(height: 16),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading(title: 'ค่าเฉลี่ย'),
                      const SizedBox(height: 14),
                      if (stats.isEmpty)
                        const Text('บันทึกการนอนสัก 2–3 คืนแล้วค่าเฉลี่ยจะขึ้นที่นี่',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textFaint))
                      else ...[
                        _StatRow(
                          label: 'เวลานอนเฉลี่ย',
                          value: _duration(stats.averageMinutes.round()),
                          hint: 'เป้า ${_duration(goals.sleepTargetMinutes)}',
                          progress: stats.averageMinutes / goals.sleepTargetMinutes,
                        ),
                        const SizedBox(height: 14),
                        _StatRow(
                          label: 'คุณภาพที่รู้สึก',
                          value: '${(stats.averageQuality * 100).round()}%',
                          hint: 'จาก ${stats.nightCount} คืน',
                          progress: stats.averageQuality,
                        ),
                        const SizedBox(height: 14),
                        _StatRow(
                          label: 'เวลาเข้านอนสม่ำเสมอ',
                          value: '${(stats.bedtimeConsistency * 100).round()}%',
                          hint: 'ตื่นกลางดึกเฉลี่ย ${stats.averageAwakenings.toStringAsFixed(1)} ครั้ง',
                          progress: stats.bedtimeConsistency,
                        ),
                      ],
                    ],
                  ),
                ),

                if (tips.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AppCard(
                    color: _category.softColor,
                    borderColor: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.sleep),
                            SizedBox(width: 8),
                            Text('คำแนะนำจากข้อมูลของคุณ',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        for (final tip in tips) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(Icons.circle, size: 5, color: AppColors.sleep),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(tip,
                                    style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.text)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                const SectionHeading(title: 'ประวัติการนอน'),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('ยังไม่มีบันทึก — กดปุ่มด้านล่างเพื่อบันทึกคืนแรก',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                  )
                else
                  for (final entry in history.take(14))
                    _NightRow(
                      entry: entry,
                      score: Insights.scoreOfNight(entry, goals.sleepTargetMinutes),
                      onTap: () => _openForm(context, repo, existing: entry),
                    ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _openForm(context, repo),
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
                        Text('บันทึกการนอน',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
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

/// การ์ดหัวเรื่อง — สรุปการนอนของคืนล่าสุด หรือชวนให้บันทึกถ้ายังไม่มี
class _LastNightCard extends StatelessWidget {
  final SleepEntry? entry;
  final int targetMinutes;
  final VoidCallback onRecord;

  const _LastNightCard({required this.entry, required this.targetMinutes, required this.onRecord});

  @override
  Widget build(BuildContext context) {
    final night = entry;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sleep, Color(0xFF232B4D)],
        ),
      ),
      child: night == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ยังไม่ได้บันทึกการนอนเมื่อคืน',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                const Text('ใช้เวลาไม่ถึงนาที แล้วแอปจะสรุปให้ว่าอะไรทำให้หลับดีหรือไม่ดี',
                    style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.45)),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onRecord,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('บันทึกเลย',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('เมื่อคืน',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                        const SizedBox(height: 6),
                        Text(SleepScreen._duration(night.durationMinutes),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('เป้า ${SleepScreen._duration(targetMinutes)}',
                            style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: (night.durationMinutes / targetMinutes).clamp(0, 1).toDouble(),
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _HeroStat(value: night.bedTime, label: 'เข้านอน'),
                    const SizedBox(width: 20),
                    _HeroStat(value: night.wakeTime, label: 'ตื่นนอน'),
                    const SizedBox(width: 20),
                    _HeroStat(value: night.quality.label, label: 'คุณภาพ'),
                    const SizedBox(width: 20),
                    _HeroStat(value: '${night.awakenings}', label: 'ตื่นกลางดึก'),
                  ],
                ),
              ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
      ],
    );
  }
}

/// แท่งชั่วโมงนอนของแต่ละคืน พร้อมเส้นประระดับเป้าหมาย
class _WeekChart extends StatelessWidget {
  final List<SleepEntry> nights;
  final int targetMinutes;

  const _WeekChart({required this.nights, required this.targetMinutes});

  @override
  Widget build(BuildContext context) {
    // สเกลแกนตั้งอิงคืนที่นอนนานสุด แต่ไม่ต่ำกว่าเป้า เพื่อให้เห็นว่ายังไม่ถึงเป้า
    final maxMinutes = nights
        .map((n) => n.durationMinutes)
        .fold<int>(targetMinutes, (a, b) => a > b ? a : b);

    return Column(
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: nights.map((n) {
              final ratio = (n.durationMinutes / maxMinutes).clamp(0.04, 1.0);
              final score = Insights.scoreOfNight(n, targetMinutes);
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text((n.durationMinutes / 60).toStringAsFixed(1),
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 62 * ratio,
                      decoration: BoxDecoration(
                        color: SleepScreen._scoreColor(score),
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
          children: nights
              .map((n) => Expanded(
                    child: Text(
                      SleepScreen._thaiWeekdayShort[n.nightDate.weekday - 1],
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

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final double progress;

  const _StatRow({required this.label, required this.value, required this.hint, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.sleep)),
          ],
        ),
        const SizedBox(height: 4),
        Text(hint, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
        const SizedBox(height: 7),
        ProgressTrack(value: progress.clamp(0, 1).toDouble(), color: AppColors.sleep),
      ],
    );
  }
}

class _NightRow extends StatelessWidget {
  final SleepEntry entry;
  final int score;
  final VoidCallback onTap;

  const _NightRow({required this.entry, required this.score, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = SleepScreen._scoreColor(score);
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
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: Text('$score',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(SleepScreen._nightLabel(entry),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.bedTime} – ${entry.wakeTime} • ${SleepScreen._duration(entry.durationMinutes)} • ${entry.quality.label}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                  if (entry.factors.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      entry.factors.map((f) => f.label).join(' • '),
                      style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

/// ช่องที่กดแล้วเปิด picker แทนการพิมพ์ — ให้หน้าตาเหมือน AuthField
class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        const SizedBox(height: 7),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: AppColors.textFaint),
                const SizedBox(width: 10),
                Text(value, style: const TextStyle(fontSize: 14, color: AppColors.text)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FactorChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FactorChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.sleep : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.sleep : AppColors.border, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// เปิด/ปิดการเตือน "ถึงเวลาเข้านอน" — เวลาแนะนำมาจากเวลาตื่นเฉลี่ยจริงลบเป้าเวลานอน
///
/// เบื้องหลังคือกิจกรรมประจำสัปดาห์ 7 รายการในตารางเวลา จึงใช้ระบบเตือนเดิมทั้งหมด
class _BedtimeReminderCard extends StatefulWidget {
  final List<SleepEntry> nights;
  final GoalSettings goals;

  const _BedtimeReminderCard({required this.nights, required this.goals});

  @override
  State<_BedtimeReminderCard> createState() => _BedtimeReminderCardState();
}

class _BedtimeReminderCardState extends State<_BedtimeReminderCard> {
  final ScheduleRepository _schedule = ScheduleRepository();

  void _syncReminders() {
    // ตั้งเตือนใหม่ไม่สำเร็จไม่ควรทำให้การบันทึกล้ม — ข้อมูลลงตารางไปแล้ว
    unawaited(NotificationService.syncScheduleReminders().catchError((Object e) {
      debugPrint('ตั้งการแจ้งเตือนใหม่ไม่สำเร็จ: $e');
      return 0;
    }));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _turnOn(String time) async {
    await BedtimeReminder.apply(_schedule, time);
    _syncReminders();
    _toast('ตั้งเตือนเข้านอน $time น. ทุกวันแล้ว');
  }

  Future<void> _turnOff() async {
    await BedtimeReminder.remove(_schedule);
    _syncReminders();
    _toast('ปิดการเตือนเข้านอนแล้ว');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _schedule.listenable(),
      builder: (context, _) {
        final suggested = BedtimeReminder.suggestedTime(widget.nights, widget.goals);
        final current = BedtimeReminder.currentTime(_schedule);
        final on = current != null;
        final targetHours = (widget.goals.sleepTargetMinutes / 60).toStringAsFixed(
          widget.goals.sleepTargetMinutes % 60 == 0 ? 0 : 1,
        );

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('เตือนให้เข้านอน',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          on
                              ? 'เตือนทุกวัน $current น. (เพิ่มในตารางเวลาให้แล้ว)'
                              : suggested == null
                                  ? 'บันทึกการนอนสักคืนก่อน เพื่อให้คำนวณเวลาจากเวลาตื่นจริงของคุณ'
                                  : 'แนะนำ $suggested น. = ตื่นเฉลี่ยลบเป้า $targetHours ชม.',
                          style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: on,
                    activeTrackColor: SleepScreen._category.color,
                    onChanged: suggested == null && !on
                        ? null
                        : (v) => v ? _turnOn(suggested ?? current!) : _turnOff(),
                  ),
                ],
              ),
              // เวลาตื่นเฉลี่ยขยับเมื่อบันทึกคืนใหม่ — เสนอให้ปรับ แต่ไม่แก้ให้เองเงียบ ๆ
              if (on && suggested != null && suggested != current) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _turnOn(suggested),
                    style: TextButton.styleFrom(
                      foregroundColor: SleepScreen._category.color,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.update_rounded, size: 18),
                    label: Text('ปรับเป็น $suggested น. ตามการนอนล่าสุด',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
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

/// ย้อนหลัง 30 คืน — แท่งรายคืน (คืนที่ไม่ได้บันทึกเป็นขีดจาง) + ค่าเฉลี่ยรายสัปดาห์
///
/// กราฟ 7 คืนด้านบนตอบว่า "สัปดาห์นี้เป็นยังไง" ส่วนการ์ดนี้ตอบว่า "ดีขึ้นหรือแย่ลง"
class _MonthHistoryCard extends StatelessWidget {
  final SleepHistory history;
  final int targetMinutes;

  const _MonthHistoryCard({required this.history, required this.targetMinutes});

  @override
  Widget build(BuildContext context) {
    final logged = history.loggedCount;
    final stats = history.stats;
    final weekly = history.weeklyAverages();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'ย้อนหลัง 30 คืน',
            action: logged == 0 ? null : 'บันทึกแล้ว $logged คืน',
          ),
          const SizedBox(height: 12),
          if (logged == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('ยังไม่มีบันทึกย้อนหลัง — บันทึกการนอนสัก 2–3 คืนแล้วกลับมาดูแนวโน้มได้',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
            )
          else ...[
            _MonthChart(history: history, targetMinutes: targetMinutes),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MonthStat(value: SleepScreen._duration(stats.averageMinutes.round()), label: 'เฉลี่ยต่อคืน'),
                ),
                Expanded(
                  child: _MonthStat(
                    value: '${history.nightsMeetingTarget(targetMinutes)} / $logged',
                    label: 'คืนที่ถึงเป้า',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('ค่าเฉลี่ยรายสัปดาห์ (เก่า → ใหม่)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < weekly.length; i++) ...[
                  if (i != 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            weekly[i] == null ? '–' : (weekly[i]! / 60).toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: weekly[i] == null ? AppColors.textFaint : AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('สัปดาห์ ${i + 1}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textFaint)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// แท่งบาง ๆ 30 คืน — สีตามคะแนนของคืนนั้น เส้นประคือระดับเป้าหมาย
class _MonthChart extends StatelessWidget {
  final SleepHistory history;
  final int targetMinutes;

  const _MonthChart({required this.history, required this.targetMinutes});

  static String _dayLabel(DateTime d) => '${d.day} ${SleepScreen._thaiMonthShort[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    // สเกลอิงคืนที่นอนนานสุด แต่ไม่ต่ำกว่าเป้า เพื่อให้เส้นเป้าหมายอยู่ในกรอบเสมอ
    final maxMinutes = history.maxMinutes > targetMinutes ? history.maxMinutes : targetMinutes;
    const chartHeight = 86.0;
    final targetRatio = maxMinutes == 0 ? 0.0 : targetMinutes / maxMinutes;
    // เป้าอยู่สูงกว่าทุกคืน = เส้นไปทับขอบบนพอดี ซ่อนไปเลยดีกว่าให้ดูเหมือนขอบกราฟ
    final showTargetLine = maxMinutes > targetMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              // เส้นเป้าหมาย วางใต้แท่งเพื่อให้ยังอ่านแท่งได้ชัด — ใช้สีหลักให้ต่างจาก
              // ขีดจางของคืนที่ยังไม่ได้บันทึก ไม่งั้นจะดูเป็นเส้นเดียวกัน
              if (showTargetLine)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: chartHeight * targetRatio,
                  child: Container(height: 1, color: AppColors.primary.withValues(alpha: 0.45)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: history.nights.map((n) {
                  final score = n.entry == null ? 0 : Insights.scoreOfNight(n.entry!, targetMinutes);
                  final ratio = maxMinutes == 0 ? 0.0 : (n.durationMinutes / maxMinutes).clamp(0.0, 1.0);
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: n.isLogged ? chartHeight * ratio : 3,
                      decoration: BoxDecoration(
                        color: n.isLogged ? SleepScreen._scoreColor(score) : AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_dayLabel(history.nights.first.date),
                style: const TextStyle(fontSize: 10, color: AppColors.textFaint)),
            Text(
                showTargetLine
                    ? 'เส้นน้ำเงิน = เป้า ${(targetMinutes / 60).toStringAsFixed(targetMinutes % 60 == 0 ? 0 : 1)} ชม.'
                    : 'ขีดจาง = คืนที่ยังไม่ได้บันทึก',
                style: const TextStyle(fontSize: 10, color: AppColors.textFaint)),
            Text(_dayLabel(history.nights.last.date),
                style: const TextStyle(fontSize: 10, color: AppColors.textFaint)),
          ],
        ),
      ],
    );
  }
}

class _MonthStat extends StatelessWidget {
  final String value;
  final String label;

  const _MonthStat({required this.value, required this.label});

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

/// เทียบคุณภาพการนอนกับสิ่งที่กิน (คาเฟอีนบ่าย / มื้อดึก) จากบันทึกโภชนาการ
///
/// เดาคาเฟอีนจากชื่อเมนูที่ผู้ใช้พิมพ์ จึงเป็นการ "ช่วยสังเกต" ไม่ใช่ข้อสรุปทางการแพทย์
class _FoodComparisonCard extends StatelessWidget {
  final List<SleepEntry> nights;
  final int targetMinutes;

  const _FoodComparisonCard({required this.nights, required this.targetMinutes});

  @override
  Widget build(BuildContext context) {
    final comparisons = SleepNutritionInsights.compare(
      nights,
      MealRepository(),
      sleepTargetMinutes: targetMinutes,
    );
    final ready = comparisons.where((c) => c.hasEnoughData).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: 'การนอนกับสิ่งที่กิน'),
          const SizedBox(height: 4),
          const Text('เทียบคืนที่กินกับคืนที่ไม่ได้กิน จากมื้ออาหารที่บันทึกไว้ในวันนั้น',
              style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textFaint)),
          const SizedBox(height: 12),
          if (ready.isEmpty)
            const Text(
              'ยังเทียบไม่ได้ — ต้องมีทั้งคืนที่กินและคืนที่ไม่ได้กินอย่างละ 2 คืนขึ้นไป '
              '(บันทึกมื้ออาหารของวันนั้นด้วย แล้วแอปจะจับให้เอง)',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textFaint),
            )
          else
            for (var i = 0; i < ready.length; i++) ...[
              if (i != 0) const Divider(height: 20, color: AppColors.border),
              _ComparisonRow(comparison: ready[i]),
            ],
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final SleepComparison comparison;

  const _ComparisonRow({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final worseWithIt = comparison.delta > 0;
    final color = comparison.isMeaningful
        ? (worseWithIt ? SleepScreen._dangerColor : SleepScreen._category.color)
        : AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(comparison.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
            Text(
              comparison.isMeaningful
                  ? '${worseWithIt ? '−' : '+'}${comparison.delta.abs().round()}%'
                  : 'พอ ๆ กัน',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'คืนที่กิน ${comparison.withScore.round()}% (${comparison.withCount} คืน) • '
          'คืนที่ไม่ได้กิน ${comparison.withoutScore.round()}% (${comparison.withoutCount} คืน)',
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        if (comparison.isMeaningful && worseWithIt) ...[
          const SizedBox(height: 4),
          Text(comparison.advice, style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textFaint)),
        ],
      ],
    );
  }
}
