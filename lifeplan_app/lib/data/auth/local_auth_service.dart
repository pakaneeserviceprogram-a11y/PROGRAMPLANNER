import '../../models/user_profile.dart';
import '../id_gen.dart';
import '../repositories/user_repository.dart';
import 'auth_service.dart';

/// บัญชีในเครื่องล้วน (Hive) — ยังไม่มีการยืนยันตัวตนจริงกับเซิร์ฟเวอร์
///
/// **รหัสผ่านไม่ถูกเก็บและไม่ถูกตรวจสอบ** ตรวจแค่รูปแบบให้ผู้ใช้เห็นข้อความเหมือนของจริง
/// เพื่อให้เปลี่ยนไปใช้ [AuthService] ตัวจริงแล้ว UX ไม่เปลี่ยน (ดูขั้นตอนที่ `auth_service.dart`)
class LocalAuthService implements AuthService {
  final UserRepository _users;

  LocalAuthService({UserRepository? users}) : _users = users ?? UserRepository();

  @override
  bool get isReal => false;

  @override
  UserProfile? currentUser() => _users.getCurrent();

  @override
  Future<AuthResult> signInWithEmail({required String email, required String password}) async {
    final error = AuthValidation.email(email) ?? AuthValidation.password(password);
    if (error != null) return AuthResult.failure(error);

    final clean = email.trim();
    final existing = _users.getCurrent();
    // อีเมลเดิม = บัญชีเดิม (ชื่อ/เป้าหมายที่ตั้งไว้ไม่หาย), อีเมลใหม่ = สร้างบัญชีในเครื่องให้เลย
    final user = existing != null && existing.email.toLowerCase() == clean.toLowerCase()
        ? existing
        : UserProfile(id: newId(), name: clean.split('@').first, email: clean, authProvider: AuthProvider.email);
    await _users.save(user);
    return AuthResult.success(user);
  }

  @override
  Future<AuthResult> registerWithEmail({required String name, required String email, required String password}) async {
    final error = AuthValidation.name(name) ?? AuthValidation.email(email) ?? AuthValidation.password(password);
    if (error != null) return AuthResult.failure(error);

    final user = UserProfile(id: newId(), name: name.trim(), email: email.trim(), authProvider: AuthProvider.email);
    await _users.save(user);
    return AuthResult.success(user);
  }

  @override
  Future<AuthResult> signInWithProvider(AuthProvider provider) async {
    if (provider == AuthProvider.email) {
      return const AuthResult.failure('ต้องใช้ signInWithEmail สำหรับการเข้าสู่ระบบด้วยอีเมล');
    }

    // ยังไม่ได้ต่อ Google/Apple จริง — ใช้บัญชีเดิมถ้ามี ไม่งั้นสร้างบัญชีตัวอย่างในเครื่อง
    final user = _users.getCurrent() ??
        UserProfile(id: newId(), name: 'ผู้ใช้ LifePlan', email: 'you@example.com', authProvider: provider);
    await _users.save(user);
    return AuthResult.success(user);
  }

  @override
  Future<void> signOut() => _users.signOut();
}
