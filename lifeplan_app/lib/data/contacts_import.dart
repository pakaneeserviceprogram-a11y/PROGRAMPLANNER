import 'package:flutter/widgets.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../models/client.dart';
import 'contact_search.dart';
import 'id_gen.dart';

/// รายชื่อหนึ่งคนจากสมุดโทรศัพท์ของเครื่อง (อ่านอย่างเดียว)
class DeviceContact {
  final String id;
  final String name;
  final String? phone;

  const DeviceContact({required this.id, required this.name, this.phone});
}

/// ตัวกลางอ่านสมุดโทรศัพท์ — แยกไว้เพื่อให้เทสต์ใส่ข้อมูลปลอมแทนปลั๊กอินจริงได้
/// (ปลั๊กอินต้องมีเครื่อง Android/iOS จริงถึงจะทำงาน)
abstract class ContactsSource {
  static ContactsSource instance = DeviceContactsSource();

  /// ขอสิทธิ์อ่านรายชื่อ — false = ผู้ใช้ไม่อนุญาต
  Future<bool> requestPermission();

  Future<List<DeviceContact>> fetchAll();
}

class DeviceContactsSource implements ContactsSource {
  @override
  Future<bool> requestPermission() async {
    final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
    // limited = ผู้ใช้เลือกแชร์เฉพาะบางรายชื่อ (iOS 18+) ก็ยังอ่านที่เลือกไว้ได้
    return status == fc.PermissionStatus.granted || status == fc.PermissionStatus.limited;
  }

  @override
  Future<List<DeviceContact>> fetchAll() async {
    final contacts = await fc.FlutterContacts.getAll(
      properties: {fc.ContactProperty.name, fc.ContactProperty.phone},
    );
    return [
      for (final c in contacts)
        DeviceContact(
          // id ว่าง = รายชื่อที่ระบบยังไม่ให้ id มา ใช้ชื่อ+เบอร์แทนเพื่อให้ติ๊กเลือกได้
          id: c.id ?? '${c.displayName}-${c.phones.isEmpty ? '' : c.phones.first.number}',
          name: (c.displayName ?? '').trim(),
          phone: c.phones.isEmpty ? null : c.phones.first.number.trim(),
        ),
    ];
  }
}

/// คัดรายชื่อจากสมุดโทรศัพท์มาเป็นผู้มุ่งหวัง
///
/// **ข้อมูลไม่ออกจากเครื่อง** — อ่านมาแสดงให้ผู้ใช้ติ๊กเลือก แล้วบันทึกเฉพาะคนที่เลือกลง Hive
/// (คนที่ไม่ได้เลือกไม่ถูกเก็บไว้ที่ไหนเลย)
class ContactsImport {
  ContactsImport._();

  /// รายชื่อที่ยังไม่มีในระบบ เรียงตามชื่อ
  ///
  /// กันซ้ำด้วย **เบอร์โทร** เป็นหลัก (เทียบเฉพาะตัวเลข) เพราะชื่อในสมุดโทรศัพท์
  /// มักเขียนไม่เหมือนที่บันทึกในแอป เช่น "สมชาย (ประกัน)" กับ "คุณสมชาย ใจดี"
  static List<DeviceContact> suggest(Iterable<DeviceContact> contacts, Iterable<Client> existing) {
    final takenPhones = {
      for (final c in existing)
        if (c.phone != null) _digits(c.phone!),
    }..remove('');
    final takenNames = {for (final c in existing) c.name.trim().toLowerCase()};

    final result = <DeviceContact>[];
    final seenPhones = <String>{};
    for (final contact in contacts) {
      // บางรายชื่อในเครื่องมีแต่ช่องว่าง/เบอร์อย่างเดียว — ไม่มีชื่อก็เลือกไม่ถูกอยู่ดี
      if (contact.name.trim().isEmpty) continue;
      final phone = contact.phone == null ? '' : _digits(contact.phone!);
      if (phone.isNotEmpty && takenPhones.contains(phone)) continue;
      if (phone.isEmpty && takenNames.contains(contact.name.trim().toLowerCase())) continue;
      // รายชื่อเดียวกันที่มีหลายเบอร์จะถูกอ่านมาหลายรายการ — เก็บอันแรกพอ
      if (phone.isNotEmpty && !seenPhones.add(phone)) continue;
      result.add(contact);
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// กรองด้วยคำค้น (ชื่อหรือเบอร์) — คำค้นว่าง = คืนทั้งหมด
  static List<DeviceContact> search(List<DeviceContact> contacts, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return contacts;
    final qDigits = _digits(q);
    return contacts.where((c) {
      if (c.name.toLowerCase().contains(q)) return true;
      return qDigits.isNotEmpty && c.phone != null && _digits(c.phone!).contains(qDigits);
    }).toList();
  }

  /// แปลงเป็นลูกค้าใหม่ พร้อมติดแหล่งที่มาว่ามาจากสมุดโทรศัพท์
  static Client toClient(DeviceContact contact) {
    final clean = contact.name.replaceAll(RegExp('คุณ'), '').trim();
    return Client(
      id: newId(),
      name: contact.name,
      initials: clean.isEmpty ? '?' : clean.characters.take(2).toString(),
      policyLabel: 'จากสมุดโทรศัพท์ • ลูกค้าใหม่',
      stage: ClientStage.newLead,
      phone: contact.phone != null && ContactSearch.phoneUrl(contact.phone!) != null ? contact.phone : null,
      source: ClientSource.phonebook,
    );
  }

  static String _digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');
}

/// ใช้ใน debug เท่านั้น — ให้หน้าจอทดสอบได้โดยไม่ต้องมีสมุดโทรศัพท์จริง
@visibleForTesting
class FakeContactsSource implements ContactsSource {
  final bool granted;
  final List<DeviceContact> contacts;

  FakeContactsSource({this.granted = true, this.contacts = const []});

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<List<DeviceContact>> fetchAll() async => contacts;
}
