import '../../models/user_profile.dart';
import 'local_auth_service.dart';

/// ผลของการเข้าสู่ระบบ/สมัครสมาชิก — ล้มเหลวได้พร้อมข้อความไทยที่เอาไปโชว์ SnackBar ได้เลย
class AuthResult {
  final UserProfile? user;
  final String? errorMessage;

  const AuthResult.success(UserProfile this.user) : errorMessage = null;
  const AuthResult.failure(String this.errorMessage) : user = null;

  bool get isSuccess => user != null;
}

/// ชั้นกลางของการยืนยันตัวตน — หน้า Login/Register เรียกผ่านตัวนี้เท่านั้น
/// ไม่แตะ `UserRepository` ตรง ๆ เพื่อให้สลับไปใช้บริการจริงได้โดยไม่ต้องแก้หน้าจอ
///
/// ตอนนี้ค่าเริ่มต้นคือ [LocalAuthService] = **บัญชีในเครื่อง ยังไม่ยืนยันตัวตนจริง**
/// (รหัสผ่านไม่ได้ถูกเก็บหรือตรวจสอบ — อย่าเอาไปใช้กับข้อมูลที่ต้องการความปลอดภัยจริง)
///
/// **วิธีต่อของจริงภายหลัง** (เช่น Firebase Auth):
/// 1. เพิ่ม `firebase_core` + `firebase_auth` (และ `google_sign_in` / `sign_in_with_apple` ถ้าต้องการปุ่มโซเชียล) ใน `pubspec.yaml`
/// 2. วาง `android/app/google-services.json` (+ ลงทะเบียน SHA-1 ของ keystore ทั้ง debug และ release)
/// 3. เขียน `FirebaseAuthService implements AuthService` ในโฟลเดอร์นี้ — แปลง `User` ของ Firebase เป็น [UserProfile]
///    (ใช้ `uid` เป็น `id` เพื่อให้ตรงกับ `userId` ที่ DATA_MODEL ออกแบบไว้สำหรับ sync)
/// 4. `AuthService.instance = FirebaseAuthService();` ใน `main()` ก่อน `runApp` — หน้าจอไม่ต้องแก้
/// 5. ตั้ง `isReal` เป็น true แถบ "โหมดทดลอง" บนหน้าเข้าสู่ระบบจะหายไปเอง
abstract class AuthService {
  /// จุดสลับ implementation — ตั้งค่าใน `main()` ก่อน `runApp` ได้
  static AuthService instance = LocalAuthService();

  /// บัญชีที่ล็อกอินอยู่ (null = ยังไม่ได้ล็อกอิน)
  UserProfile? currentUser();

  Future<AuthResult> signInWithEmail({required String email, required String password});

  Future<AuthResult> registerWithEmail({required String name, required String email, required String password});

  /// ปุ่ม Google / Apple — [provider] ต้องไม่ใช่ [AuthProvider.email]
  Future<AuthResult> signInWithProvider(AuthProvider provider);

  Future<void> signOut();

  /// false = ยังเป็นบัญชีในเครื่อง (หน้าเข้าสู่ระบบจะขึ้นแถบบอกผู้ใช้ว่าเป็นโหมดทดลอง)
  bool get isReal;
}

/// ตรวจข้อมูลที่ผู้ใช้กรอก — แยกไว้ตรงกลางเพื่อให้ implementation จริงใช้ข้อความเดียวกัน
/// คืน null = ผ่าน, คืนข้อความ = ไม่ผ่าน
class AuthValidation {
  AuthValidation._();

  static const minPasswordLength = 8;

  static String? email(String email) {
    if (email.trim().isEmpty) return 'กรุณากรอกอีเมล';
    // ตรวจแค่รูปแบบพื้นฐาน (มี @ และจุดหลัง @) ที่เหลือให้เซิร์ฟเวอร์ตรวจตอนต่อของจริง
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
    return ok ? null : 'รูปแบบอีเมลไม่ถูกต้อง';
  }

  static String? password(String password) =>
      password.length < minPasswordLength ? 'รหัสผ่านต้องมีอย่างน้อย $minPasswordLength ตัวอักษร' : null;

  static String? name(String name) => name.trim().isEmpty ? 'กรุณากรอกชื่อ' : null;

  static String? passwordConfirm(String password, String confirm) =>
      password == confirm ? null : 'รหัสผ่านไม่ตรงกัน';
}
