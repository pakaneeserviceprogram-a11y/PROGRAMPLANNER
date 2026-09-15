import 'package:flutter/material.dart';

import '../data/repositories/user_repository.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import 'auth/login_screen.dart';
import 'goal_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userRepo = UserRepository();
    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: userRepo.listenable(),
        builder: (context, _, _) {
          final user = userRepo.getCurrent() ??
              const UserProfile(id: '-', name: 'ผู้ใช้ LifePlan', email: 'you@example.com', authProvider: AuthProvider.email);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              const Text('โปรไฟล์', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 20),
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        user.name.characters.first,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(user.email, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text(_providerLabel(user.authProvider), style: const TextStyle(fontSize: 11, color: AppColors.textFaint, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ProfileRow(
                      icon: Icons.track_changes_rounded,
                      label: 'ตั้งค่าเป้าหมาย',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoalSettingsScreen())),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    const _ProfileRow(icon: Icons.notifications_none_rounded, label: 'การแจ้งเตือน'),
                    const Divider(height: 1, color: AppColors.border),
                    const _ProfileRow(icon: Icons.lock_outline_rounded, label: 'ความเป็นส่วนตัว & ความปลอดภัย'),
                    const Divider(height: 1, color: AppColors.border),
                    const _ProfileRow(icon: Icons.help_outline_rounded, label: 'ช่วยเหลือ'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await userRepo.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('ออกจากระบบ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _providerLabel(AuthProvider p) => switch (p) {
        AuthProvider.email => 'เข้าสู่ระบบด้วยอีเมล',
        AuthProvider.google => 'เข้าสู่ระบบด้วย Google',
        AuthProvider.apple => 'เข้าสู่ระบบด้วย Apple',
      };
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ProfileRow({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.textMuted),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint, size: 20),
          ],
        ),
      ),
    );
  }
}
