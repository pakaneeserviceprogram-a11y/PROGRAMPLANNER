import 'package:flutter/material.dart';

import '../data/insights.dart';
import '../data/repositories/client_repository.dart';
import '../data/repositories/exercise_repository.dart';
import '../data/repositories/finance_repository.dart';
import '../data/repositories/goal_settings_repository.dart';
import '../data/repositories/schedule_repository.dart';
import '../data/repositories/skill_track_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/work_task_repository.dart';
import '../models/client.dart';
import '../models/life_category.dart';
import '../models/work_task.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/icon_tile.dart';
import '../widgets/progress_track.dart';
import '../widgets/section_heading.dart';
import 'crm_screen.dart';
import 'exercise_screen.dart';
import 'finance_screen.dart';
import 'learning_screen.dart';
import 'work_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  static const _weekdayNames = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
  static const _monthNames = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  String _thaiDateLabel() {
    final now = DateTime.now();
    return 'วัน${_weekdayNames[now.weekday - 1]}ที่ ${now.day} ${_monthNames[now.month - 1]} ${now.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    final exerciseRepo = ExerciseRepository();
    final workRepo = WorkTaskRepository();
    final clientRepo = ClientRepository();
    final financeRepo = FinanceRepository();
    final skillRepo = SkillTrackRepository();
    final scheduleRepo = ScheduleRepository();
    final userRepo = UserRepository();
    final goalsRepo = GoalSettingsRepository();

    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          exerciseRepo.listenable(),
          workRepo.listenable(),
          clientRepo.listenable(),
          financeRepo.listenable(),
          skillRepo.listenable(),
          scheduleRepo.listenable(),
          userRepo.listenable(),
          goalsRepo.listenable(),
        ]),
        builder: (context, _) {
          final scores = Insights.categoryScores();
          final overall = Insights.overallScore(scores);

          final exerciseItems = exerciseRepo.getAll();
          final exerciseDone = exerciseItems.where((e) => e.isDone).length;
          final exerciseTarget = goalsRepo.get().exerciseWeeklyTarget;

          final tasks = workRepo.getAll();
          final tasksToday = tasks.where((t) => t.status != TaskStatus.done).length;

          final clients = clientRepo.getAll();
          final needsFollowUp = clients.where((c) => c.stage != ClientStage.closedWon).length;

          final skills = skillRepo.getAll();
          final primarySkill = skills.isNotEmpty ? skills.first : null;

          final totalActivities = exerciseItems.length + tasks.length;
          final doneActivities = exerciseDone + tasks.where((t) => t.status == TaskStatus.done).length;

          final events = scheduleRepo.getByWeekday(DateTime.now().weekday).take(3).toList();
          final user = userRepo.getCurrent();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('สวัสดีตอนเช้า', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        user != null ? user.name : 'ภาพรวมวันนี้',
                        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                      ),
                    ],
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.notifications_none_rounded, size: 19, color: AppColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(_thaiDateLabel(), style: const TextStyle(fontSize: 13, color: AppColors.textFaint)),
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ความสำเร็จวันนี้', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text('$doneActivities / $totalActivities', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 6),
                        const Text('กิจกรรมออกกำลังกาย + งานที่เสร็จแล้ว', style: TextStyle(fontSize: 12.5, color: Colors.white70)),
                      ],
                    ),
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: CircularProgressIndicator(
                              value: overall / 100,
                              strokeWidth: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.25),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          Text('$overall%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: _StatTile(icon: Icons.check_rounded, iconColor: AppColors.work, value: '$tasksToday', label: 'งานค้างอยู่')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatTile(icon: Icons.groups_rounded, iconColor: AppColors.crm, value: '$needsFollowUp', label: 'ลูกค้าต้องติดตาม')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatTile(icon: Icons.trending_up_rounded, iconColor: AppColors.finance, value: '${scores[LifeCategory.finance]}%', label: 'เป้าออมเดือนนี้')),
                ],
              ),
              const SizedBox(height: 20),

              const SectionHeading(title: 'ภาพรวมแต่ละด้าน'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _ModuleCard(
                    category: LifeCategory.exercise,
                    subtitle: '$exerciseDone / $exerciseTarget ครั้งสัปดาห์นี้',
                    progress: (scores[LifeCategory.exercise] ?? 0) / 100,
                    onTap: () => _open(context, const ExerciseScreen()),
                  ),
                  _ModuleCard(
                    category: LifeCategory.work,
                    subtitle: '$tasksToday งานที่ต้องทำ',
                    progress: (scores[LifeCategory.work] ?? 0) / 100,
                    onTap: () => _open(context, const WorkScreen()),
                  ),
                  _ModuleCard(
                    category: LifeCategory.crm,
                    subtitle: '$needsFollowUp รายต้องติดตาม',
                    progress: (scores[LifeCategory.crm] ?? 0) / 100,
                    onTap: () => _open(context, const CrmScreen()),
                  ),
                  _ModuleCard(
                    category: LifeCategory.finance,
                    subtitle: 'ออม ${scores[LifeCategory.finance]}% ของเป้าหมาย',
                    progress: (scores[LifeCategory.finance] ?? 0) / 100,
                    onTap: () => _open(context, const FinanceScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _open(context, const LearningScreen()),
                child: AppCard(
                  color: LifeCategory.learning.softColor,
                  borderColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconTile(icon: LifeCategory.learning.icon, background: LifeCategory.learning.color),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('เรียนรู้ & พัฒนาตนเอง', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                primarySkill != null ? '${primarySkill.name} • ${primarySkill.progressPercent}%' : 'ยังไม่มีเส้นทางการเรียนรู้',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(title: 'ตารางวันนี้'),
                    const SizedBox(height: 4),
                    if (events.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('ยังไม่มีกิจกรรมในตารางเวลา', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                      )
                    else
                      for (final e in events) ...[
                        const Divider(height: 24, color: AppColors.border),
                        Row(
                          children: [
                            SizedBox(width: 42, child: Text(e.time, style: const TextStyle(fontSize: 12, color: AppColors.textFaint))),
                            Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: e.category.color, shape: BoxShape.circle)),
                            Expanded(child: Text(e.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
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

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatTile({required this.icon, required this.iconColor, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final LifeCategory category;
  final String subtitle;
  final double progress;
  final VoidCallback onTap;

  const _ModuleCard({required this.category, required this.subtitle, required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: category.softColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconTile(icon: category.icon, background: category.color),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                ProgressTrack(value: progress, color: category.color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
