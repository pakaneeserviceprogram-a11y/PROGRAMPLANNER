import 'package:flutter/foundation.dart';

/// ฟีเจอร์ที่ทำงานได้เฉพาะแอปมือถือ — เวอร์ชันเว็บ (เปิดผ่าน Safari/Chrome) ซ่อนไว้
///
/// เว็บไม่มีการแจ้งเตือนตามเวลาแบบแอป, ML Kit (สแกนนามบัตร/กล่องยา) และสมุดโทรศัพท์ของเครื่อง
/// ข้อมูลอื่นทั้งหมด (Hive) ใช้ได้ปกติ โดยเก็บในเบราว์เซอร์เครื่องนั้น
class PlatformSupport {
  PlatformSupport._();

  /// เปิดเป็นเว็บ — ทดสอบตั้งค่าเป็น true ได้เพื่อจำลองหน้าตาเวอร์ชันเว็บ
  @visibleForTesting
  static bool? debugIsWebOverride;

  static bool get isWeb => debugIsWebOverride ?? kIsWeb;

  static bool get notifications => !isWeb;
  static bool get textScan => !isWeb;
  static bool get contactsImport => !isWeb;

  static const webOnlyNote = 'ใช้ได้ในแอปมือถือเท่านั้น (เวอร์ชันเว็บไม่รองรับ)';
}
