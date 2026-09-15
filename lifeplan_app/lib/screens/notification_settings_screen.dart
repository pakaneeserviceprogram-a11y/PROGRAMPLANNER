import 'package:flutter/material.dart';

import '../data/notifications.dart';
import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/schedule_repository.dart';
import '../models/app_settings.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/form_sheet.dart';

const _minuteOptions = [0, 5, 10, 15, 30, 60];

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

  @override
  Widget build(BuildContext context) {
    final eventCount = ScheduleRepository().getAll().length;

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
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('เตือนกิจกรรมในตารางเวลา',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('เตือนซ้ำทุกสัปดาห์ตามวันและเวลาที่ตั้งไว้',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _settings.scheduleRemindersEnabled,
                    onChanged: _busy
                        ? null
                        : (v) => _apply(_settings.copyWith(scheduleRemindersEnabled: v), askPermission: true),
                  ),
                ],
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
                    onChanged: _busy || !_settings.scheduleRemindersEnabled
                        ? null
                        : (v) => _apply(_settings.copyWith(remindMinutesBefore: v!)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _settings.scheduleRemindersEnabled
                        ? 'ตั้งเตือนไว้ ${_scheduledCount ?? eventCount} รายการ จากกิจกรรมทั้งหมด $eventCount รายการ'
                        : 'ตอนนี้ปิดการเตือนอยู่ — มีกิจกรรมในตาราง $eventCount รายการ',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
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
              child: AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('ส่งการแจ้งเตือนทดสอบ',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    if (_busy)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ถ้าไม่ได้รับการแจ้งเตือน ให้ตรวจว่าเครื่องไม่ได้เปิดโหมดห้ามรบกวน '
              'และแอปไม่ได้ถูกจำกัดการทำงานเบื้องหลัง (ตั้งค่า > แอป > LifePlan > แบตเตอรี่)',
              style: TextStyle(fontSize: 12, color: AppColors.textFaint, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
