import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/notifications.dart';
import '../data/reminder_watcher.dart';
import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/schedule_repository.dart';
import '../models/life_category.dart';
import '../models/schedule_event.dart';
import '../theme/app_colors.dart';
import 'icon_tile.dart';

const _weekdayFullLabels = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];

/// เลื่อนเตือนไปอีกกี่นาทีเมื่อผู้ใช้กด "เตือนอีกครั้ง"
const snoozeMinutes = 5;

/// ป๊อปอัปกลางจอเมื่อถึงเวลากิจกรรม
///
/// เสียงและการสั่นมาจากการแจ้งเตือนของระบบ (ดู `NotificationService`) ไม่ใช่จากตัวป๊อปอัป
/// จะได้ไม่ดังซ้อนกันสองที ตัวป๊อปอัปจึงสั่นสั้น ๆ อย่างเดียวเป็นการเน้นย้ำ
class ReminderPopup extends StatelessWidget {
  final ScheduleEvent event;
  final int minutesBefore;

  const ReminderPopup({super.key, required this.event, this.minutesBefore = 0});

  /// เปิดป๊อปอัป แล้วคืนค่า true ถ้าผู้ใช้กด "เตือนอีกครั้ง"
  static Future<bool> show(BuildContext context, ScheduleEvent event, {int minutesBefore = 0}) async {
    final snoozed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // ต้องกดปุ่มเอง ไม่งั้นแตะพลาดแล้วปิดไปโดยไม่ทันอ่าน
      barrierColor: Colors.black54,
      builder: (_) => ReminderPopup(event: event, minutesBefore: minutesBefore),
    );
    return snoozed ?? false;
  }

  String get _headline =>
      minutesBefore == 0 ? 'ถึงเวลาแล้ว' : 'อีก $minutesBefore นาทีจะถึงเวลา';

  @override
  Widget build(BuildContext context) {
    final category = event.category;
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(icon: category.icon, background: category.color, size: 44, iconSize: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_headline,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: category.color)),
                      const SizedBox(height: 2),
                      Text('วัน${_weekdayFullLabels[event.weekday - 1]} ${event.time} น.',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(event.title,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.3)),
            if (event.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(event.subtitle!,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.45)),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: category.softColor, borderRadius: BorderRadius.circular(999)),
              child: Text(category.label,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: category.color)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppColors.textMuted,
                    ),
                    child: const Text('เตือนอีกใน $snoozeMinutes นาที',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('รับทราบ', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
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

/// ครอบทั้งแอปไว้ คอยเปิด [ReminderPopup] เมื่อถึงเวลากิจกรรม
/// หรือเมื่อผู้ใช้กดการแจ้งเตือนจากแถบสถานะ
///
/// ใช้ [navigatorKey] แทน context ของตัวเอง เพราะตัวนี้อยู่เหนือ Navigator ของ MaterialApp
class ReminderHost extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const ReminderHost({super.key, required this.navigatorKey, required this.child});

  @override
  State<ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends State<ReminderHost> with WidgetsBindingObserver {
  final _schedule = ScheduleRepository();
  final _settingsRepo = AppSettingsRepository();
  late final ReminderWatcher _watcher = ReminderWatcher(onDue: _enqueue);

  /// เก็บไว้เป็นตัวเดียว — `listenable()` สร้างอ็อบเจ็กต์ใหม่ทุกครั้งที่เรียก
  /// ถ้าเรียกซ้ำตอน dispose จะถอด listener ผิดตัวแล้วค้างเป็น subscription ลอย
  late final ValueListenable<Box<Map>> _settingsListenable = _settingsRepo.listenable();

  final _queue = <DueReminder>[];
  final _snoozeTimers = <Timer>[];
  StreamSubscription<String>? _tapSub;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsListenable.addListener(_applySettings);
    _applySettings();

    // กดการแจ้งเตือนขณะแอปเปิดค้างอยู่
    _tapSub = NotificationService.tappedEventIds.listen(_showEventById);
    // กดการแจ้งเตือนตอนแอปยังไม่ได้เปิด — ต้องถามจาก plugin เอง
    unawaited(_showLaunchEvent());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsListenable.removeListener(_applySettings);
    _tapSub?.cancel();
    for (final timer in _snoozeTimers) {
      timer.cancel();
    }
    _watcher.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // หยุดตรวจตอนแอปอยู่เบื้องหลัง (Android จะไปใช้การแจ้งเตือนของระบบแทน)
    // แล้วเริ่มใหม่ตอนกลับมา เพื่อให้จับการเตือนที่เพิ่งเลยไปได้ด้วย
    if (state == AppLifecycleState.resumed) {
      _applySettings();
    } else {
      _watcher.stop();
    }
  }

  void _applySettings() {
    final settings = _settingsRepo.get();
    if (settings.scheduleRemindersEnabled && settings.popupEnabled) {
      _watcher.start();
    } else {
      _watcher.stop();
    }
  }

  Future<void> _showLaunchEvent() async {
    try {
      final id = await NotificationService.launchEventId();
      if (id != null) _showEventById(id);
    } catch (e) {
      // ไม่มี plugin (เช่นตอนรันเทส/บนเว็บ) — ไม่ใช่เรื่องที่ต้องทำให้แอปล้ม
      debugPrint('อ่านการแจ้งเตือนที่เปิดแอปไม่ได้: $e');
    }
  }

  void _showEventById(String eventId) {
    for (final event in _schedule.getAll()) {
      if (event.id != eventId) continue;
      _enqueue(DueReminder(event: event, remindAt: DateTime.now(), minutesBefore: 0));
      return;
    }
    // ไม่เจอ = กิจกรรมถูกลบไปแล้วหลังตั้งเตือน — ไม่ต้องเด้งอะไร
  }

  void _enqueue(DueReminder due) {
    _queue.add(due);
    unawaited(_pump());
  }

  /// เปิดป๊อปอัปทีละใบจนคิวหมด (กิจกรรมหลายรายการเวลาเดียวกันจะไม่ทับกัน)
  Future<void> _pump() async {
    if (_showing) return;
    _showing = true;
    try {
      while (_queue.isNotEmpty) {
        final due = _queue.removeAt(0);
        final context = widget.navigatorKey.currentContext;
        if (context == null || !context.mounted) return;

        unawaited(HapticFeedback.heavyImpact());
        final snoozed = await ReminderPopup.show(context, due.event, minutesBefore: due.minutesBefore);
        if (snoozed) _snooze(due.event);
      }
    } finally {
      _showing = false;
    }
  }

  void _snooze(ScheduleEvent event) {
    // ตั้งการแจ้งเตือนของระบบไว้ด้วย เผื่อผู้ใช้ปิดแอปไปก่อนครบเวลา
    unawaited(NotificationService.snooze(event, const Duration(minutes: snoozeMinutes)).catchError((Object e) {
      debugPrint('ตั้งเตือนซ้ำไม่สำเร็จ: $e');
    }));
    late final Timer timer;
    timer = Timer(const Duration(minutes: snoozeMinutes), () {
      _snoozeTimers.remove(timer);
      _enqueue(DueReminder(event: event, remindAt: DateTime.now(), minutesBefore: 0));
    });
    _snoozeTimers.add(timer);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
