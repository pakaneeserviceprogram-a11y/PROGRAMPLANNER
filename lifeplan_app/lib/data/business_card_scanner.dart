import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/client.dart';
import 'contact_search.dart';
import 'id_gen.dart';

/// ข้อมูลที่แกะได้จากนามบัตรหนึ่งใบ (ช่องไหนอ่านไม่ได้ = null ให้ผู้ใช้พิมพ์เอง)
class BusinessCardFields {
  final String? name;
  final String? phone;
  final String? email;
  final String? company;
  final String? website;

  /// ข้อความดิบทั้งใบ เผื่อผู้ใช้อยากคัดลอกส่วนที่แอปแกะไม่ได้
  final String rawText;

  const BusinessCardFields({
    this.name,
    this.phone,
    this.email,
    this.company,
    this.website,
    this.rawText = '',
  });

  bool get isEmpty => name == null && phone == null && email == null && company == null && website == null;
}

/// ตัวกลางอ่านตัวอักษรจากรูป — แยกไว้ให้เทสต์ใส่ข้อความปลอมแทนได้
/// และเผื่อสลับไปใช้เครื่องอ่านที่รองรับภาษาไทยภายหลัง
abstract class CardTextRecognizer {
  static CardTextRecognizer instance = MlKitCardTextRecognizer();

  /// คืนข้อความทั้งหมดที่อ่านได้จากไฟล์รูป
  Future<String> recognize(String imagePath);
}

/// ML Kit ของ Google — ประมวลผลในเครื่อง ไม่ส่งรูปขึ้นคลาวด์ ไม่ต้องใช้ API key
///
/// **รองรับอักษรละติน ไม่รองรับภาษาไทย** — ชื่อ/ที่อยู่ภาษาไทยบนนามบัตรจะอ่านไม่ออก
/// ส่วนที่ได้ผลดีคือเบอร์โทร อีเมล เว็บไซต์ และชื่อบริษัทภาษาอังกฤษ
class MlKitCardTextRecognizer implements CardTextRecognizer {
  @override
  Future<String> recognize(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}

/// แกะข้อความจากนามบัตรเป็นช่อง ๆ
///
/// เป็นฟังก์ชันล้วน (ไม่แตะกล้อง/ปลั๊กอิน) จึงเทสต์ด้วยข้อความจริงจากนามบัตรได้ตรง ๆ
class BusinessCardParser {
  BusinessCardParser._();

  /// เบอร์ไทย: 0xx-xxx-xxxx, 0xxxxxxxxx, +66 xx xxx xxxx, มีวงเล็บ/เว้นวรรค/จุดคั่นได้
  static final _phonePattern = RegExp(r'(?:\+66|0)[\d\-\s().]{7,15}\d');
  static final _emailPattern = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final _websitePattern = RegExp(r'(?:https?://)?(?:www\.)[\w-]+\.[\w.-]+|(?:https?://)[\w-]+\.[\w.-]+');

  /// คำที่บอกว่าบรรทัดนั้นคือชื่อบริษัท
  static const companyHints = ['บริษัท', 'จำกัด', 'หจก', 'ห้างหุ้นส่วน', 'co., ltd', 'co.,ltd', 'co ltd', 'ltd', 'company', 'corporation', 'group'];

  /// คำที่บอกว่าบรรทัดนั้นเป็นตำแหน่ง/ป้ายกำกับ ไม่ใช่ชื่อคน
  static const _notNameHints = [
    'tel', 'mobile', 'phone', 'fax', 'email', 'e-mail', 'line', 'www', 'address', 'โทร', 'มือถือ', 'แฟกซ์', 'ที่อยู่',
    'manager', 'director', 'executive', 'agent', 'consultant', 'sales', 'ตัวแทน', 'ผู้จัดการ', 'ที่ปรึกษา',
  ];

  static BusinessCardFields parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final phone = _firstMatch(lines, _phonePattern, clean: _cleanPhone);
    final email = _firstMatch(lines, _emailPattern);
    final website = _firstMatch(lines, _websitePattern);
    final company = lines.firstWhere(
      (l) => companyHints.any((h) => l.toLowerCase().contains(h)),
      orElse: () => '',
    );

    // ชื่อคน = บรรทัดแรกที่ไม่ใช่บริษัท/เบอร์/อีเมล/เว็บ/ตำแหน่ง และไม่ได้มีแต่ตัวเลข
    final name = lines.firstWhere(
      (l) {
        final lower = l.toLowerCase();
        if (l == company) return false;
        if (_phonePattern.hasMatch(l) || _emailPattern.hasMatch(l) || _websitePattern.hasMatch(l)) return false;
        if (_notNameHints.any(lower.contains)) return false;
        if (!RegExp(r'[A-Za-zก-๙]').hasMatch(l)) return false;
        return l.length >= 3;
      },
      orElse: () => '',
    );

    return BusinessCardFields(
      name: _orNull(name),
      phone: phone,
      email: email,
      company: _orNull(company),
      website: website,
      rawText: rawText,
    );
  }

  /// สร้างลูกค้าใหม่จากข้อมูลที่แกะได้ — ชื่อว่างใช้ชื่อบริษัทแทน
  static Client toClient(BusinessCardFields fields, {String? nameOverride, String? phoneOverride}) {
    final name = (nameOverride ?? fields.name ?? fields.company ?? '').trim();
    final clean = name.replaceAll(RegExp('คุณ'), '').trim();
    final phone = (phoneOverride ?? fields.phone)?.trim();

    return Client(
      id: newId(),
      name: name,
      initials: clean.isEmpty ? '?' : clean.characters.take(2).toString(),
      policyLabel: [
        if (fields.company != null && fields.company != name) fields.company!,
        'จากนามบัตร',
      ].join(' • '),
      stage: ClientStage.newLead,
      phone: phone != null && phone.isNotEmpty && ContactSearch.phoneUrl(phone) != null ? phone : null,
      profileUrl: fields.website,
      source: ClientSource.businessCard,
    );
  }

  static String? _firstMatch(List<String> lines, RegExp pattern, {String Function(String)? clean}) {
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        final value = match.group(0)!.trim();
        return clean == null ? value : clean(value);
      }
    }
    return null;
  }

  /// เก็บเฉพาะตัวเลขกับ + นำหน้า แล้วตัดสัญลักษณ์คั่นทิ้ง
  static String _cleanPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^\d+]'), '');
    return digits.startsWith('+') ? '+${digits.replaceAll('+', '')}' : digits;
  }

  static String? _orNull(String value) => value.trim().isEmpty ? null : value.trim();
}

/// ใช้ในเทสต์ — คืนข้อความที่กำหนดไว้โดยไม่แตะกล้องหรือ ML Kit
@visibleForTesting
class FakeCardTextRecognizer implements CardTextRecognizer {
  final String text;
  final Object? error;

  FakeCardTextRecognizer(this.text, {this.error});

  @override
  Future<String> recognize(String imagePath) async {
    if (error != null) throw error!;
    return text;
  }
}
