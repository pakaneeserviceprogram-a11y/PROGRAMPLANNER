import 'package:flutter/material.dart';

import '../data/insights.dart';
import '../data/repositories/client_repository.dart';
import '../data/repositories/exercise_repository.dart';
import '../data/repositories/finance_repository.dart';
import '../data/repositories/goal_settings_repository.dart';
import '../data/repositories/meal_repository.dart';
import '../data/repositories/skill_track_repository.dart';
import '../data/repositories/sleep_repository.dart';
import '../data/repositories/water_repository.dart';
import '../data/repositories/work_task_repository.dart';
import '../models/life_category.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/progress_track.dart';
import '../widgets/section_heading.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final exerciseRepo = ExerciseRepository();
    final workRepo = WorkTaskRepository();
    final clientRepo = ClientRepository();
    final financeRepo = FinanceRepository();
    final skillRepo = SkillTrackRepository();
    final goalsRepo = GoalSettingsRepository();
    final mealRepo = MealRepository();
    final waterRepo = WaterRepository();
    final sleepRepo = SleepRepository();

    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          exerciseRepo.listenable(),
          workRepo.listenable(),
          clientRepo.listenable(),
          financeRepo.listenable(),
          skillRepo.listenable(),
          goalsRepo.listenable(),
          mealRepo.listenable(),
          waterRepo.listenable(),
          sleepRepo.listenable(),
        ]),
        builder: (context, _) {
          final scores = Insights.categoryScores();
          final overall = Insights.overallScore(scores);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const Text('ความคืบหน้า', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 2),
              const Text('คำนวณจากข้อมูลจริงที่บันทึกไว้ในแต่ละด้าน', style: TextStyle(fontSize: 13, color: AppColors.textFaint)),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('คะแนนรวมตอนนี้', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text.rich(TextSpan(children: [
                          TextSpan(text: '$overall ', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                          const TextSpan(text: '/ 100', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white70)),
                        ])),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 64,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: LifeCategory.values.map((c) {
                          final v = (scores[c] ?? 0) / 100;
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 64 * v.clamp(0.04, 1.0),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55 + 0.35 * v), borderRadius: BorderRadius.circular(6)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: LifeCategory.values
                          .map((c) => Expanded(
                                child: Text(
                                  c.label.split(' ').first,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.white70),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(title: 'แยกตามด้าน'),
                    const SizedBox(height: 12),
                    for (final entry in scores.entries) ...[
                      _ScoreRow(category: entry.key, score: entry.value),
                      if (entry.key != LifeCategory.values.last) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(title: 'สรุปตัวเลข'),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Badge(icon: Icons.directions_run_rounded, color: AppColors.exercise, label: '${exerciseRepo.getAll().where((e) => e.isDone).length}\nครั้งออกกำลังกาย'),
                        _Badge(icon: Icons.check_circle_rounded, color: AppColors.work, label: '${workRepo.getAll().where((t) => t.status.name == 'done').length}\nงานเสร็จแล้ว'),
                        _Badge(icon: Icons.groups_rounded, color: AppColors.crm, label: '${clientRepo.getAll().where((c) => c.stage.name == 'closedWon').length}\nปิดการขาย'),
                        _Badge(icon: Icons.bedtime_rounded, color: AppColors.sleep, label: '${sleepRepo.getAll().length}\nคืนที่บันทึก'),
                        _Badge(icon: Icons.menu_book_rounded, color: AppColors.learning, label: '${skillRepo.getAll().length}\nเส้นทางเรียนรู้'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final LifeCategory category;
  final int score;

  const _ScoreRow({required this.category, required this.score});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(category.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('$score%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 6),
        ProgressTrack(value: score / 100, color: category.color),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _Badge({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
