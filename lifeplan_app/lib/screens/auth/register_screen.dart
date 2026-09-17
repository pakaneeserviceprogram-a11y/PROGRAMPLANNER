import 'package:flutter/material.dart';

import '../../data/auth/auth_service.dart';
import '../../models/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/back_button_circle.dart';
import '../root_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _auth = AuthService.instance;
  bool _agreed = false;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _createAccount(AuthProvider provider) async {
    if (_busy) return;
    if (!_agreed) {
      _toast('กรุณายอมรับข้อกำหนดการใช้งานและนโยบายความเป็นส่วนตัว');
      return;
    }
    // ยืนยันรหัสผ่านเป็นเรื่องของฟอร์ม (AuthService ไม่รู้จักช่องนี้) ที่เหลือให้ service ตรวจ
    if (provider == AuthProvider.email) {
      final mismatch = AuthValidation.passwordConfirm(_passwordController.text, _confirmController.text);
      if (mismatch != null) {
        _toast(mismatch);
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final result = provider == AuthProvider.email
          ? await _auth.registerWithEmail(
              name: _nameController.text,
              email: _emailController.text,
              password: _passwordController.text,
            )
          : await _auth.signInWithProvider(provider);

      if (!mounted) return;
      if (!result.isSuccess) {
        _toast(result.errorMessage!);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              Row(
                children: [
                  const BackButtonCircle(),
                  const SizedBox(width: 12),
                  const Text('สร้างบัญชีใหม่', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'เริ่มวางแผนชีวิตของคุณตั้งแต่วันนี้',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textFaint),
              ),
              const SizedBox(height: 26),
              AuthField(label: 'ชื่อ-นามสกุล', hint: 'ชื่อของคุณ', controller: _nameController),
              const SizedBox(height: 16),
              AuthField(label: 'อีเมล', hint: 'you@example.com', controller: _emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              AuthField(label: 'รหัสผ่าน', hint: 'อย่างน้อย 8 ตัวอักษร', controller: _passwordController, obscureText: true),
              const SizedBox(height: 16),
              AuthField(label: 'ยืนยันรหัสผ่าน', hint: 'พิมพ์รหัสผ่านอีกครั้ง', controller: _confirmController, obscureText: true),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 19,
                    height: 19,
                    child: Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      side: const BorderSide(color: AppColors.border, width: 1.8),
                      activeColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.6),
                        children: [
                          TextSpan(text: 'ฉันยอมรับ'),
                          TextSpan(text: 'ข้อกำหนดการใช้งาน', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          TextSpan(text: 'และ'),
                          TextSpan(text: 'นโยบายความเป็นส่วนตัว', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              PrimaryButton(label: 'สร้างบัญชี', onPressed: () => _createAccount(AuthProvider.email)),
              const SizedBox(height: 18),
              const OrDivider(label: 'หรือ'),
              const SizedBox(height: 18),
              GoogleSignInButton(label: 'สมัครด้วย Google', onPressed: () => _createAccount(AuthProvider.google)),
              const SizedBox(height: 14),
              AppleSignInButton(label: 'สมัครด้วย Apple', onPressed: () => _createAccount(AuthProvider.apple)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('มีบัญชีอยู่แล้ว?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
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
