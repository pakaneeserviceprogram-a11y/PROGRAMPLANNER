import 'package:flutter/material.dart';

import '../data/id_gen.dart';
import '../data/repositories/learning_streak_repository.dart';
import '../data/repositories/skill_track_repository.dart';
import '../models/skill_track.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/form_sheet.dart';
import '../widgets/icon_tile.dart';
import '../widgets/progress_track.dart';
import '../widgets/section_heading.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  static const _icons = [
    Icons.language_rounded,
    Icons.show_chart_rounded,
    Icons.calculate_rounded,
    Icons.psychology_rounded,
  ];

  /// ฟอร์มเดียวใช้ทั้งเพิ่มเส้นทางใหม่ (existing = null) และแก้ไขเส้นทางเดิม
  Future<void> _openTrackForm(BuildContext context, SkillTrackRepository repo, {SkillTrack? existing}) async {
    final nameController = TextEditingController(text: existing?.name);
    final subtitleController = TextEditingController(text: existing?.subtitle);
    final progressController = TextEditingController(text: existing != null ? '${existing.progressPercent}' : null);

    await showAppFormSheet(
      context: context,
      title: existing == null ? 'เพิ่มเส้นทางการเรียนรู้' : 'แก้ไขเส้นทางการเรียนรู้',
      submitLabel: 'บันทึก',
      footerBuilder: existing == null
          ? null
          : (sheetCtx) => FormDeleteButton(
                pageContext: context,
                label: 'ลบเส้นทางนี้',
                confirmTitle: 'ลบเส้นทางการเรียนรู้นี้?',
                confirmMessage: '“${existing.name}” และความคืบหน้าที่บันทึกไว้จะถูกลบ (สตรีคการเรียนรู้ไม่หาย)',
                doneMessage: 'ลบ “${existing.name}” แล้ว',
                onDelete: () => repo.delete(existing.id),
              ),
      bodyBuilder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthField(label: 'ชื่อสกิล', hint: 'เช่น ภาษาญี่ปุ่น', controller: nameController),
          const SizedBox(height: 14),
          AuthField(label: 'รายละเอียด', hint: 'เช่น ระดับเริ่มต้น', controller: subtitleController),
          if (existing != null) ...[
            const SizedBox(height: 14),
            AuthField(label: 'ความคืบหน้า (%)', hint: '0–100', controller: progressController, keyboardType: TextInputType.number),
          ],
        ],
      ),
      onSubmit: () async {
        final name = nameController.text.trim();
        if (name.isEmpty) return;
        final subtitle = subtitleController.text.trim();
        final progress = int.tryParse(progressController.text.trim()) ?? existing?.progressPercent ?? 0;
        await repo.put(SkillTrack(
          id: existing?.id ?? newId(),
          name: name,
          subtitle: subtitle.isEmpty ? 'เพิ่งเริ่มต้น' : subtitle,
          progressPercent: progress.clamp(0, 100),
          isPrimary: existing?.isPrimary ?? false,
        ));
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final skillRepo = SkillTrackRepository();
    final streakRepo = LearningStreakRepository();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: skillRepo.listenable(),
          builder: (context, _, _) {
            final tracks = skillRepo.getAll();
            return ValueListenableBuilder(
              valueListenable: streakRepo.listenable(),
              builder: (context, _, _) {
                final streak = streakRepo.get();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    const Row(
                      children: [
                        BackButtonCircle(),
                        SizedBox(width: 12),
                        Expanded(child: Text('เรียนรู้ & พัฒนาตนเอง', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.learning, Color(0xFF7A2FB0)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('สตรีคการเรียนรู้', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                                  const SizedBox(height: 4),
                                  Text('${streak.currentStreakDays} วันติดต่อกัน', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                                ],
                              ),
                              const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 34),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            streak.loggedToday ? 'วันนี้เรียนแล้ว ${streak.lessonsLoggedToday} บทเรียน' : 'ยังไม่ได้เรียนวันนี้ — แตะ "เรียนต่อ" เพื่อบันทึก',
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('เส้นทางการเรียนรู้ของฉัน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        GestureDetector(
                          onTap: () => _openTrackForm(context, skillRepo),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.center,
                            child: const Icon(Icons.add_rounded, size: 16, color: AppColors.text),
                          ),
                        ),
                      ],
                    ),
                    if (tracks.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('แตะการ์ดเพื่อแก้ไขหรือลบ', style: TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                      ),
                    const SizedBox(height: 12),
                    if (tracks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('ยังไม่มีเส้นทางการเรียนรู้ — กดปุ่ม + เพื่อเพิ่ม', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                      )
                    else
                      for (int i = 0; i < tracks.length; i++)
                        _SkillCard(
                          track: tracks[i],
                          icon: _icons[i % _icons.length],
                          onEdit: () => _openTrackForm(context, skillRepo, existing: tracks[i]),
                          onContinue: () async {
                            await skillRepo.put(tracks[i].copyWith(progressPercent: (tracks[i].progressPercent + 4).clamp(0, 100)));
                            await streakRepo.logSessionToday();
                          },
                        ),
                    const SizedBox(height: 4),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeading(title: 'บทเรียนถัดไปที่แนะนำ'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconTile(icon: Icons.play_arrow_rounded, background: AppColors.learningSoft, foreground: AppColors.learning),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Daily Conversation: Business English', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                    SizedBox(height: 2),
                                    Text('15 นาที • บทที่ 14', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  final SkillTrack track;
  final IconData icon;
  final VoidCallback onContinue;
  final VoidCallback onEdit;

  const _SkillCard({required this.track, required this.icon, required this.onContinue, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: track.isPrimary ? AppColors.learningSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconTile(
                      icon: icon,
                      background: track.isPrimary ? AppColors.learning : AppColors.learningSoft,
                      foreground: track.isPrimary ? Colors.white : AppColors.learning,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(track.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: track.progressPercent >= 100 ? null : onContinue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: track.progressPercent >= 100 ? AppColors.surface2 : AppColors.learning,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      track.progressPercent >= 100 ? 'ครบแล้ว' : 'เรียนต่อ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: track.progressPercent >= 100 ? AppColors.textMuted : Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ProgressTrack(value: track.progressPercent / 100, color: AppColors.learning),
          ],
        ),
      ),
    );
  }
}
