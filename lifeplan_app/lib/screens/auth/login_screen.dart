import 'package:flutter/material.dart';

import '../../data/auth/auth_service.dart';
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
  final _auth = AuthService.instance;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// การยืนยันตัวตนทั้งหมดอยู่หลัง [AuthService] — หน้าจอนี้ไม่รู้ว่าเป็นบัญชีในเครื่องหรือของจริง
  Future<void> _signIn(AuthProvider provider) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = provider == AuthProvider.email
          ? await _auth.signInWithEmail(email: _emailController.text, password: _passwordController.text)
          : await _auth.signInWithProvider(provider);

      if (!mounted) return;
      if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RootShell()),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              const SizedBox(height: 24),
              if (!_auth.isReal) const _PrototypeNotice(),
              const SizedBox(height: 12),
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

/// บอกตรง ๆ ว่าบัญชียังอยู่ในเครื่อง — ซ่อนอัตโนมัติเมื่อต่อ AuthService ตัวจริง (isReal = true)
class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'โหมดทดลอง: บัญชีเก็บในเครื่องนี้เท่านั้น ยังไม่ได้ยืนยันตัวตนกับเซิร์ฟเวอร์จริง',
              style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
