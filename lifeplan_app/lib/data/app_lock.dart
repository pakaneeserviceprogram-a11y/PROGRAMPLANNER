import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// ล็อกแอปด้วยลายนิ้วมือ/ใบหน้า/PIN ของมือถือ
///
/// แอปเก็บข้อมูลลูกค้าในเครื่อง และการเข้าสู่ระบบด้วยอีเมลไม่ได้ตรวจรหัสผ่าน (บัญชีในเครื่อง)
/// ตัวป้องกันจริงจึงเป็นล็อกของมือถือเอง — ไม่ต้องจำรหัสเพิ่ม และลืมไม่ได้
class AppLock {
  AppLock._();

  static final _auth = LocalAuthentication();

  /// เครื่องนี้ล็อกได้ไหม (มีลายนิ้วมือ/PIN/รูปแบบ ตั้งไว้) — เว็บล็อกไม่ได้
  @visibleForTesting
  static Future<bool> Function()? debugIsAvailable;

  @visibleForTesting
  static Future<AppLockResult> Function()? debugAuthenticate;

  static Future<bool> isAvailable() async {
    if (debugIsAvailable != null) return debugIsAvailable!();
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      // ไม่มีปลั๊กอิน (เช่นในเทสต์) หรือเครื่องไม่รองรับ — ไม่ล็อก ดีกว่าล็อกจนเปิดแอปไม่ได้
      return false;
    }
  }

  static Future<AppLockResult> authenticate({String reason = 'ปลดล็อก LifePlan เพื่อดูข้อมูลลูกค้า'}) async {
    if (debugAuthenticate != null) return debugAuthenticate!();
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // ยอมให้ใช้ PIN/รูปแบบแทนลายนิ้วมือได้ — เครื่องที่ไม่มีเซนเซอร์ก็ล็อกได้
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? AppLockResult.unlocked : AppLockResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout =>
          AppLockResult.canceled,
        LocalAuthExceptionCode.noCredentialsSet => AppLockResult.notAvailable,
        _ => AppLockResult.failed,
      };
    } catch (_) {
      return AppLockResult.failed;
    }
  }
}

enum AppLockResult { unlocked, canceled, failed, notAvailable }

extension AppLockResultX on AppLockResult {
  String? get message => switch (this) {
        AppLockResult.unlocked => null,
        AppLockResult.canceled => null,
        AppLockResult.failed => 'ปลดล็อกไม่สำเร็จ ลองอีกครั้ง',
        AppLockResult.notAvailable => 'มือถือยังไม่ได้ตั้งล็อกหน้าจอ — ตั้งใน การตั้งค่าเครื่อง ก่อน',
      };
}
