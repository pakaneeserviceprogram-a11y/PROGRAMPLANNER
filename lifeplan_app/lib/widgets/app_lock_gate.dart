import 'package:flutter/material.dart';

import '../data/app_lock.dart';
import '../data/repositories/app_settings_repository.dart';
import '../theme/app_colors.dart';

/// คลุมทั้งแอป: ล็อกตอนเปิด และล็อกอีกครั้งเมื่อกลับมาจากพื้นหลังเกิน [relockAfter]
///
/// หน้าจอข้างใต้ยังอยู่ (ไม่เสียสถานะที่กรอกค้างไว้) แต่ถูกบังมิดและกดไม่ได้จนกว่าจะปลดล็อก
class AppLockGate extends StatefulWidget {
  final Widget child;

  /// ล็อกตั้งแต่เฟรมแรก — `main()` เช็กการตั้งค่าและความพร้อมของเครื่องไว้ก่อนแล้ว
  /// จะได้ไม่มีจังหวะที่ข้อมูลลูกค้าโผล่ขึ้นมาแวบหนึ่งก่อนล็อก
  final bool lockedAtStart;

  /// เครื่องนี้ล็อกได้ (มีล็อกหน้าจอ) — false = ไม่ล็อกเลย แม้เปิดตั้งค่าไว้
  final bool deviceSupported;

  final Duration relockAfter;

  const AppLockGate({
    super.key,
    required this.child,
    this.lockedAtStart = false,
    this.deviceSupported = false,
    this.relockAfter = const Duration(seconds: 30),
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  late bool _locked = widget.lockedAtStart;
  bool _authenticating = false;
  DateTime? _backgroundAt;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _lockEnabled => widget.deviceSupported && AppSettingsRepository().get().appLockEnabled;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // หน้าใส่ PIN ของระบบทำให้แอปเข้าพื้นหลังชั่วคราว — ไม่นับเป็นการออกจากแอป
    if (_authenticating) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _backgroundAt == null ? Duration.zero : DateTime.now().difference(_backgroundAt!);
      _backgroundAt = null;
      if (!_locked && _lockEnabled && away >= widget.relockAfter) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });
    final result = await AppLock.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      // เครื่องถอดล็อกหน้าจอออกไปแล้ว — ปล่อยเข้า ไม่งั้นผู้ใช้ติดอยู่นอกแอปตัวเอง
      if (result == AppLockResult.unlocked || result == AppLockResult.notAvailable) _locked = false;
      _message = result.message;
      _backgroundAt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ซ่อนทั้งภาพและการอ่านหน้าจอ (TalkBack) ตอนล็อก
        ExcludeSemantics(
          excluding: _locked,
          child: IgnorePointer(ignoring: _locked, child: widget.child),
        ),
        if (_locked) Positioned.fill(child: _LockScreen(busy: _authenticating, message: _message, onUnlock: _unlock)),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  final bool busy;
  final String? message;
  final VoidCallback onUnlock;

  const _LockScreen({required this.busy, required this.message, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('app-lock-screen'),
      color: AppColors.bg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 56, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text('LifePlan ล็อกอยู่',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 8),
                const Text('ใช้ลายนิ้วมือ ใบหน้า หรือรหัสปลดล็อกมือถือ เพื่อดูข้อมูลลูกค้า',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textMuted)),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFFD64545))),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    key: const ValueKey('app-unlock'),
                    onPressed: busy ? null : onUnlock,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('ปลดล็อก', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
