import 'package:flutter/material.dart';

import '../data/app_lock.dart';
import '../data/repositories/app_settings_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/back_button_circle.dart';

/// ความเป็นส่วนตัว & ความปลอดภัย — เปิด/ปิดล็อกแอป และบอกตรง ๆ ว่าข้อมูลอยู่ที่ไหน
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final _settings = AppSettingsRepository();
  bool? _available;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppLock.isAvailable().then((v) {
      if (mounted) setState(() => _available = v);
    });
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggle(bool enable) async {
    setState(() => _busy = true);
    // ปิดล็อกต้องยืนยันตัวตนก่อน — ไม่งั้นใครหยิบเครื่องไปก็ปิดล็อกได้
    // เปิดล็อกก็ยืนยันด้วย เพื่อเช็กว่าเครื่องปลดล็อกได้จริงก่อนจะล็อกครั้งหน้า
    final result = await AppLock.authenticate(
      reason: enable ? 'ยืนยันเพื่อเปิดล็อกแอป' : 'ยืนยันเพื่อปิดล็อกแอป',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != AppLockResult.unlocked) {
      if (result.message != null) _toast(result.message!);
      return;
    }
    await _settings.save(_settings.get().copyWith(appLockEnabled: enable));
    if (!mounted) return;
    setState(() {});
    _toast(enable ? 'เปิดล็อกแอปแล้ว' : 'ปิดล็อกแอปแล้ว');
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _settings.get().appLockEnabled;
    final available = _available;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Row(
              children: [
                BackButtonCircle(),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ความเป็นส่วนตัว & ความปลอดภัย',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // การ์ดมีพื้นหลังของตัวเอง — ต้องมี Material คั่นไม่งั้นเอฟเฟกต์กดของสวิตช์ถูกบัง
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      key: const ValueKey('app-lock-switch'),
                      contentPadding: EdgeInsets.zero,
                      value: enabled && available == true,
                      onChanged: (available == true && !_busy) ? _toggle : null,
                      title: const Text(
                        'ล็อกแอปด้วยลายนิ้วมือ / PIN',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: const Text(
                        'ขอปลดล็อกทุกครั้งที่เปิดแอป และเมื่อกลับมาหลังออกจากแอปเกิน 30 วินาที',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  if (available == false) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'มือถือเครื่องนี้ยังไม่ได้ตั้งล็อกหน้าจอ — ตั้งลายนิ้วมือหรือ PIN ใน การตั้งค่าเครื่อง แล้วกลับมาเปิดที่นี่',
                      key: ValueKey('app-lock-unavailable'),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFFD64545),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ข้อมูลของคุณอยู่ที่ไหน',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  _Point(
                    'ข้อมูลทั้งหมดอยู่ในมือถือเครื่องนี้เท่านั้น แอปไม่ได้ส่งขึ้นเซิร์ฟเวอร์',
                  ),
                  _Point(
                    'อีเมลที่ใช้เข้าแอปเป็นแค่ชื่อบัญชีในเครื่อง ไม่ได้ใช้ป้องกันข้อมูล — ตัวป้องกันคือล็อกแอปด้านบน',
                  ),
                  _Point(
                    'ไฟล์สำรองข้อมูลมีข้อมูลลูกค้าครบทุกราย เก็บไว้ที่ส่วนตัว อย่าส่งเข้ากลุ่มแชท',
                  ),
                  _Point(
                    'สรุปพอร์ตที่ส่งเข้า LINE ไม่ใส่ชื่อลูกค้า เว้นแต่คุณเปิดเอง',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final String text;

  const _Point(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 5, color: AppColors.textMuted),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
