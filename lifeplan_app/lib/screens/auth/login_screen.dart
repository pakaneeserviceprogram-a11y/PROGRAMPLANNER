import 'package:flutter/material.dart';

import '../../data/id_gen.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_widgets.dart';
import '../root_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userRepo = UserRepository();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn(AuthProvider provider) async {
    final email = _emailController.text.trim();
    if (provider == AuthProvider.email && email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกอีเมล')));
      return;
    }

    // Reuse an existing local account if this email already signed up,
    // otherwise create one on the fly — this is an on-device prototype
    // with no real backend auth yet (see README "แผนขั้นตอนถัดไป").
    final existing = _userRepo.getCurrent();
    final user = existing ??
        UserProfile(
          id: newId(),
          name: provider == AuthProvider.email ? email.split('@').first : 'ผู้ใช้ LifePlan',
          email: provider == AuthProvider.email ? email : 'you@example.com',
          authProvider: provider,
        );
    await _userRepo.save(user);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            children: [
              const SizedBox(height: 56),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.track_changes_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 14),
              const Text('LifePlan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 4),
              const Text(
                'วางแผนและวัดผลทุกด้านของชีวิตในที่เดียว',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textFaint),
              ),
              const SizedBox(height: 36),
              AuthField(label: 'อีเมล', hint: 'you@example.com', controller: _emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 18),
              AuthField(label: 'รหัสผ่าน', hint: '••••••••', controller: _passwordController, obscureText: true),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text('ลืมรหัสผ่าน?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
              const SizedBox(height: 18),
              PrimaryButton(label: 'เข้าสู่ระบบ', onPressed: () => _signIn(AuthProvider.email)),
              const SizedBox(height: 18),
              const OrDivider(label: 'หรือเข้าสู่ระบบด้วย'),
              const SizedBox(height: 18),
              GoogleSignInButton(label: 'ดำเนินการต่อด้วย Google', onPressed: () => _signIn(AuthProvider.google)),
              const SizedBox(height: 14),
              AppleSignInButton(label: 'ดำเนินการต่อด้วย Apple', onPressed: () => _signIn(AuthProvider.apple)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ยังไม่มีบัญชี?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('สมัครสมาชิก', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
