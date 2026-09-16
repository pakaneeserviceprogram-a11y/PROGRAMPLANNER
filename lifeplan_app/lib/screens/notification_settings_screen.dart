import 'package:flutter/material.dart';

import '../data/notifications.dart';
import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/schedule_repository.dart';
import '../models/app_settings.dart';
import '../models/life_category.dart';
import '../models/schedule_event.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/form_sheet.dart';
import '../widgets/reminder_popup.dart';

const _minuteOptions = [0, 5, 10, 15, 30, 60];

/// กิจกรรมสมมติสำหรับปุ่ม "ลองดูป๊อปอัป" เมื่อผู้ใช้ยังไม่มีอะไรในตาราง
const _samplePopupEvent = ScheduleEvent(
  id: '__preview__',
  time: '09:00',
  weekday: DateTime.monday,
  title: 'ตัวอย่างกิจกรรม',
  subtitle: 'ป๊อปอัปจริงจะเด้งแบบนี้เมื่อถึงเวลาในตารางของคุณ',
  category: LifeCategory.work,
);

/// ตั้งค่าการแจ้งเตือนกิจกรรมในตารางเวลา
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _repo = AppSettingsRepository();
  late AppSettings _settings = _repo.get();
  int? _scheduledCount;
  bool _busy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _apply(AppSettings next, {bool askPermission = false}) async {
    setState(() => _busy = true);
    try {
      if (askPermission && next.scheduleRemindersEnabled) {
        final granted = await NotificationService.requestPermission();
        if (!granted) {
          _toast('ยังไม่ได้รับอนุญาตให้แจ้งเตือน — เปิดสิทธิ์ได้ที่ ตั้งค่า > แอป > LifePlan');
          return;
        }
      }

      await _repo.save(next);
      final count = await NotificationService.syncScheduleReminders();
      if (!mounted) return;
      setState(() {
        _settings = next;
        _scheduledCount = count;
      });
    } catch (e) {
      _toast('ตั้งการแจ้งเตือนไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewPopup() async {
    final events = ScheduleRepository().getAllSortedByTime();
    final event = events.isEmpty ? _samplePopupEvent : events.first;
    await ReminderPopup.show(context, event, minutesBefore: _settings.remindMinutesBefore);
  }

  @override
  Widget build(BuildContext context) {
    final eventCount = ScheduleRepository().getAll().length;
    final on = _settings.scheduleRemindersEnabled;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('การแจ้งเตือน', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AppCard(
              child: _ToggleRow(
                title: 'เตือนกิจกรรมในตารางเวลา',
                subtitle: 'เตือนซ้ำทุกสัปดาห์ตามวันและเวลาที่ตั้งไว้',
                value: on,
                onChanged: _busy
                    ? null
                    : (v) => _apply(_settings.copyWith(scheduleRemindersEnabled: v), askPermission: true),
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledDropdown<int>(
                    label: 'เตือนล่วงหน้า',
                    value: _settings.remindMinutesBefore,
                    options: _minuteOptions,
                    display: (m) => m == 0 ? 'ตรงเวลากิจกรรม' : '$m นาทีก่อนเริ่ม',
                    onChanged:
                        _busy || !on ? null : (v) => _apply(_settings.copyWith(remindMinutesBefore: v!)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    on
                        ? 'ตั้งเตือนไว้ ${_scheduledCount ?? eventCount} รายการ จากกิจกรรมทั้งหมด $eventCount รายการ'
                        : 'ตอนนี้ปิดการเตือนอยู่ — มีกิจกรรมในตาราง $eventCount รายการ',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  _ToggleRow(
                    title: 'เสียงแจ้งเตือน',
                    subtitle: 'เล่นเสียงระฆังของ LifePlan เมื่อถึงเวลา',
                    value: _settings.soundEnabled,
                    onChanged: _busy || !on ? null : (v) => _apply(_settings.copyWith(soundEnabled: v)),
                  ),
                  const Divider(height: 28, color: AppColors.border),
                  _ToggleRow(
                    title: 'สั่นเตือน',
                    subtitle: 'สั่นพร้อมกับการแจ้งเตือน',
                    value: _settings.vibrationEnabled,
                    onChanged: _busy || !on ? null : (v) => _apply(_settings.copyWith(vibrationEnabled: v)),
                  ),
                  const Divider(height: 28, color: AppColors.border),
                  _ToggleRow(
                    title: 'ป๊อปอัปกลางจอ',
                    subtitle: 'เด้งหน้าต่างเตือนทับหน้าที่ใช้อยู่ ขณะเปิดแอปค้างไว้',
                    value: _settings.popupEnabled,
                    onChanged: _busy || !on ? null : (v) => _apply(_settings.copyWith(popupEnabled: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.volume_up_outlined,
              label: 'ทดสอบเสียงและการแจ้งเตือน',
              busy: _busy,
              onTap: _busy
                  ? null
                  : () async {
                      final granted = await NotificationService.requestPermission();
                      if (!granted) {
                        _toast('ยังไม่ได้รับอนุญาตให้แจ้งเตือน');
                        return;
                      }
                      await NotificationService.showTestNotification();
                      _toast('ส่งการแจ้งเตือนทดสอบแล้ว');
                    },
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.open_in_full_rounded,
              label: 'ลองดูหน้าตาป๊อปอัป',
              busy: false,
              onTap: _busy ? null : _previewPopup,
            ),
            const SizedBox(height: 16),
            const Text(
              'เสียงและการสั่นมาจากการแจ้งเตือนของระบบ — ถ้าไม่ได้ยิน ให้ตรวจว่าเครื่องไม่ได้เปิด '
              'โหมดห้ามรบกวน/เงียบ, ระดับเสียงการแจ้งเตือนไม่ได้ถูกหรี่ไว้ '
              'และแอปไม่ได้ถูกจำกัดการทำงานเบื้องหลัง (ตั้งค่า > แอป > LifePlan > แบตเตอรี่)',
              style: TextStyle(fontSize: 12, color: AppColors.textFaint, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// แถวหัวข้อ + คำอธิบาย + สวิตช์ ที่ใช้ซ้ำทุกตัวเลือกในหน้านี้
class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = onChanged == null;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: dimmed ? AppColors.textFaint : AppColors.text,
                  )),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionCard({required this.icon, required this.label, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}
