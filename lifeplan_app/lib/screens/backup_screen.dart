import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';

/// หน้าสำรอง/กู้คืนข้อมูล — ข้อมูลทั้งหมดเก็บในเครื่องอย่างเดียว
/// ไฟล์ JSON ก้อนนี้จึงเป็นทางเดียวที่จะย้ายเครื่องหรือกู้ข้อมูลคืนได้
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = BackupService.exportToJson();
      // เขียนลงโฟลเดอร์ชั่วคราวของแอปก่อน แล้วส่งต่อผ่านแผงแชร์ของระบบ
      // ให้ผู้ใช้เลือกเองว่าจะเก็บไว้ที่ไหน (ไดรฟ์, แชท, ไฟล์ในเครื่อง)
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${BackupService.suggestedFileName()}');
      await file.writeAsString(json, encoding: utf8, flush: true);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'LifePlan backup',
        text: 'ไฟล์สำรองข้อมูล LifePlan',
      ));
    } catch (e) {
      _toast('ส่งออกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'เลือกไฟล์สำรอง LifePlan',
        type: FileType.any,
      );
      if (picked.isEmpty) return;

      final text = utf8.decode(await picked.first.readAsBytes());
      final summary = BackupService.summarize(text);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('กู้คืนข้อมูล?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ข้อมูลในเครื่องตอนนี้จะถูกแทนที่ด้วยไฟล์สำรองทั้งหมด และย้อนกลับไม่ได้',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Text('ในไฟล์มี: ${_summaryLabel(summary)}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('กู้คืน')),
          ],
        ),
      );
      if (confirmed != true) return;

      await BackupService.importFromJson(text);
      _toast('กู้คืนข้อมูลเรียบร้อย');
    } on BackupException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('กู้คืนไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _boxLabels = {
    'user_profile': 'โปรไฟล์',
    'work_tasks': 'งาน',
    'exercise_items': 'ออกกำลังกาย',
    'clients': 'ลูกค้า',
    'finance_transactions': 'รายการเงิน',
    'skill_tracks': 'การเรียนรู้',
    'schedule_events': 'ตารางเวลา',
    'goal_settings': 'เป้าหมาย',
  };

  static String _summaryLabel(Map<String, int> summary) {
    final parts = <String>[];
    for (final entry in _boxLabels.entries) {
      final count = summary[entry.key] ?? 0;
      if (count > 0) parts.add('${entry.value} $count');
    }
    return parts.isEmpty ? 'ไม่มีข้อมูล' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('สำรอง & กู้คืนข้อมูล', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ข้อมูลทั้งหมดเก็บอยู่ในเครื่องนี้เท่านั้น',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                    'ถ้าถอนการติดตั้งแอปหรือเปลี่ยนเครื่อง ข้อมูลจะหายทั้งหมด '
                    'แนะนำให้ส่งออกไฟล์สำรองเก็บไว้เป็นระยะ',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.ios_share_rounded,
              title: 'ส่งออกไฟล์สำรอง',
              subtitle: 'รวมข้อมูลทุกโมดูลเป็นไฟล์ JSON แล้วเลือกที่เก็บเอง',
              enabled: !_busy,
              onTap: _export,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.settings_backup_restore_rounded,
              title: 'กู้คืนจากไฟล์สำรอง',
              subtitle: 'แทนที่ข้อมูลในเครื่องด้วยไฟล์ที่เลือก',
              enabled: !_busy,
              danger: true,
              onTap: _import,
            ),
            if (_busy) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFB3401E) : AppColors.primary;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AppCard(
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
