/// ค้นหาข้อมูลผู้มุ่งหวัง/บริษัท โดย **เปิดหน้าค้นหาของเว็บนั้น ๆ ให้ผู้ใช้ค้นเอง**
///
/// **ทำไมไม่ดึงข้อมูลเข้าแอป**
/// - Facebook ปิดการค้นหาผู้ใช้ผ่าน API ตั้งแต่ปี 2018 และ Instagram API เข้าถึงได้เฉพาะ
///   บัญชีธุรกิจที่เราเป็นเจ้าของเอง — ไม่มีช่องทางที่ถูกกติกาให้แอปค้นรายชื่อคนอัตโนมัติ
/// - การไล่ดูดโปรไฟล์จากหน้าเว็บ (scraping) ผิดเงื่อนไขการใช้งานของ Meta และการเก็บข้อมูล
///   ส่วนบุคคลของคนที่ยังไม่ได้เป็นลูกค้าไว้ในระบบขายยังสุ่มเสี่ยงผิด PDPA
///
/// แอปจึงทำหน้าที่แค่ "ทางลัด" — ไม่เก็บอะไรอัตโนมัติ ผู้ใช้เห็นผลแล้วเลือกเองว่าจะบันทึกใคร
library;

enum ContactSource { dbd, google, facebook, instagram }

extension ContactSourceX on ContactSource {
  String get label => switch (this) {
        ContactSource.dbd => 'ข้อมูลนิติบุคคล (DBD)',
        ContactSource.google => 'ค้นทั่วไป (Google)',
        ContactSource.facebook => 'ค้นใน Facebook',
        ContactSource.instagram => 'ค้นใน Instagram',
      };

  String get hint => switch (this) {
        ContactSource.dbd => 'ชื่อบริษัท เลขทะเบียน กรรมการ จากคลังข้อมูลธุรกิจของกรมพัฒนาธุรกิจการค้า',
        ContactSource.google => 'ข่าว เว็บไซต์ หรือเบอร์ติดต่อของบริษัท/ร้าน',
        ContactSource.facebook => 'เปิดหน้าค้นหาของ Facebook พร้อมชื่อที่พิมพ์ไว้',
        ContactSource.instagram => 'เปิดหน้าค้นหาของ Instagram พร้อมชื่อที่พิมพ์ไว้',
      };
}

class ContactSearch {
  ContactSearch._();

  /// โดเมนคลังข้อมูลธุรกิจของ DBD ที่ใช้จำกัดขอบเขตการค้นด้วย Google
  static const dbdSite = 'datawarehouse.dbd.go.th';

  /// ลิงก์หน้าค้นหาของแหล่งที่เลือก — คำค้นว่าง = null (ไม่ต้องเปิดหน้าเปล่า)
  ///
  /// DBD ใช้การค้นผ่าน Google แบบจำกัดเว็บ (`site:`) แทนการยิงเข้าหน้าค้นหาภายในของ DBD
  /// เพราะรูปแบบ URL ภายในของเว็บ DBD ไม่ใช่ API สาธารณะ เปลี่ยนเมื่อไหร่ก็ได้ และหน้ารายละเอียดต้องล็อกอิน
  static Uri? urlFor(ContactSource source, String query) {
    final q = query.trim();
    if (q.isEmpty) return null;

    return switch (source) {
      ContactSource.dbd => Uri.https('www.google.com', '/search', {'q': '$q site:$dbdSite'}),
      ContactSource.google => Uri.https('www.google.com', '/search', {'q': q}),
      ContactSource.facebook => Uri.https('www.facebook.com', '/search/top', {'q': q}),
      ContactSource.instagram => Uri.https('www.instagram.com', '/explore/search/keyword/', {'q': q}),
    };
  }

  /// ลิงก์โทรออก — ตัดช่องว่าง ขีด วงเล็บทิ้ง เก็บเฉพาะตัวเลขกับ + นำหน้า
  static Uri? phoneUrl(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final digits = cleaned.replaceAll('+', '');
    if (digits.length < 8) return null; // สั้นกว่านี้ไม่น่าใช่เบอร์โทร
    return Uri(scheme: 'tel', path: cleaned.startsWith('+') ? '+$digits' : digits);
  }

  /// ลิงก์โปรไฟล์ที่ผู้ใช้วางไว้ — เติม https:// ให้ถ้าไม่ได้พิมพ์มา
  static Uri? profileUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final withScheme = value.startsWith('http://') || value.startsWith('https://') ? value : 'https://$value';
    final parsed = Uri.tryParse(withScheme);
    // ต้องมีโดเมนจริง ๆ (มีจุด) ไม่งั้นข้อความธรรมดาจะกลายเป็นลิงก์มั่ว ๆ
    if (parsed == null || !parsed.hasAuthority || !parsed.host.contains('.')) return null;
    return parsed;
  }
}
