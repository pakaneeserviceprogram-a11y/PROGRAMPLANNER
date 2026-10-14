import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/client.dart';
import 'calendar_utils.dart';
import 'id_gen.dart';

/// บริษัทที่จดทะเบียนใหม่หนึ่งราย จากข้อมูลเปิดของกรมพัฒนาธุรกิจการค้า (Open-DBD)
///
/// ข้อมูลเปิดมีแค่ทะเบียน ชื่อ ทุน ประเภทธุรกิจ และที่ตั้ง — **ไม่มีเบอร์โทร อีเมล หรือกรรมการ**
class DbdCompany {
  final String regNo;
  final String name;

  /// วันจดทะเบียนตามไฟล์ (ปี พ.ศ. เช่น "2569-09-09")
  final String regDate;
  final double capital;
  final String objectiveCode;
  final String objective;
  final String address;
  final String district;
  final String province;

  const DbdCompany({
    required this.regNo,
    required this.name,
    required this.regDate,
    required this.capital,
    required this.objectiveCode,
    required this.objective,
    required this.address,
    required this.district,
    required this.province,
  });

  /// ประเภทนิติบุคคลจากคำนำหน้าชื่อ (บจ. / หส. / หจ. / บมจ.)
  String get kind {
    for (final prefix in DbdOpenData.kinds) {
      if (name.startsWith('$prefix.')) return prefix;
    }
    return 'อื่น ๆ';
  }

  /// ชื่อจังหวัดไม่มี "จ." นำหน้า (กรุงเทพฯ ในไฟล์ไม่มีคำนำหน้าอยู่แล้ว)
  String get provinceName => province.startsWith('จ.') ? province.substring(2) : province;
}

/// ตัวกรองหน้าบริษัทตั้งใหม่ — ผลลัพธ์เรียงตามทุนจดทะเบียนจากมากไปน้อยเสมอ
class DbdFilter {
  final double minCapital;
  final String? province;
  final String? kind;
  final String keyword;

  const DbdFilter({this.minCapital = 0, this.province, this.kind, this.keyword = ''});

  DbdFilter copyWith({double? minCapital, String? province, String? kind, String? keyword, bool clearProvince = false, bool clearKind = false}) =>
      DbdFilter(
        minCapital: minCapital ?? this.minCapital,
        province: clearProvince ? null : (province ?? this.province),
        kind: clearKind ? null : (kind ?? this.kind),
        keyword: keyword ?? this.keyword,
      );

  List<DbdCompany> apply(Iterable<DbdCompany> companies) {
    final words = keyword.trim().toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final result = companies.where((c) {
      if (c.capital < minCapital) return false;
      if (province != null && c.provinceName != province) return false;
      if (kind != null && c.kind != kind) return false;
      if (words.isEmpty) return true;
      final text = '${c.name} ${c.objective} ${c.objectiveCode} ${c.district}'.toLowerCase();
      return words.every(text.contains);
    }).toList()
      ..sort((a, b) => b.capital.compareTo(a.capital));
    return result;
  }
}

/// ไฟล์ของหนึ่งเดือนที่โหลดเก็บไว้ในเครื่อง
class DbdMonthData {
  final int year; // ค.ศ.
  final int month;
  final List<DbdCompany> companies;
  final DateTime downloadedAt;

  const DbdMonthData({required this.year, required this.month, required this.companies, required this.downloadedAt});

  String get label => DbdOpenData.monthLabel(year, month);
}

/// ข้อมูลเปิด "นิติบุคคลจดทะเบียนตั้งใหม่" รายเดือนของ DBD
///
/// ที่มา: https://opendata.dbd.go.th/dataset/dataset_11_01 (สัญญาอนุญาต Open Data Common)
/// ไฟล์ CSV รายเดือนราว 6 MB / 8,000–9,000 ราย — โหลดครั้งเดียวแล้วเก็บไว้ในเครื่อง กด "อัปเดต" เมื่ออยากได้ข้อมูลใหม่
class DbdOpenData {
  DbdOpenData._();

  static const kinds = ['บมจ', 'บจ', 'หจ', 'หส'];
  static const sourceUrl = 'https://opendata.dbd.go.th/dataset/dataset_11_01';

  /// เปลี่ยนได้ในเทสต์
  static http.Client Function() clientFactory = http.Client.new;
  static Future<Directory> Function() cacheDirectory = () async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/dbd_open_data');
  };

  static Uri uriFor(int year, int month) => Uri.https(
      'openapi.dbd.go.th', '/juristic_person/registration/99_$year${month.toString().padLeft(2, '0')}_1.csv');

  static String monthLabel(int year, int month) => CalendarUtils.thaiMonthYear(DateTime(year, month));

  // ---------- CSV ----------

  /// แยก CSV ตามมาตรฐาน (ช่องที่มีจุลภาคอยู่ในเครื่องหมายคำพูด) และข้ามแถวว่าง
  /// (ไฟล์จริงมีแถวที่ทุกช่องว่างปนอยู่ราว 1 ใน 9)
  static List<DbdCompany> parseCsv(String text) {
    if (text.startsWith('﻿')) text = text.substring(1);
    final rows = _csvRows(text);
    if (rows.isEmpty) return const [];
    final header = rows.first.map((h) => h.trim()).toList();
    int col(String name) => header.indexOf(name);
    final iReg = col('เลขทะเบียน'), iName = col('ชื่อนิติบุคคล'), iDate = col('วันที่จดทะเบียน');
    final iCap = col('ทุนจดทะเบียน'), iCode = col('รหัสวัตถุประสงค์'), iObj = col('วัตถุประสงค์');
    final iAddr = col('ที่ตั้งสำนักงานใหญ่'), iDist = col('อำเภอ'), iProv = col('จังหวัด');
    if ([iReg, iName, iCap, iProv].contains(-1)) {
      throw const FormatException('รูปแบบไฟล์ DBD เปลี่ยนไป อ่านคอลัมน์ไม่ได้');
    }

    String at(List<String> r, int i) => i >= 0 && i < r.length ? r[i].trim() : '';
    return [
      for (final r in rows.skip(1))
        if (at(r, iReg).isNotEmpty && at(r, iName).isNotEmpty)
          DbdCompany(
            regNo: at(r, iReg),
            name: at(r, iName),
            regDate: at(r, iDate),
            capital: double.tryParse(at(r, iCap).replaceAll(',', '')) ?? 0,
            objectiveCode: at(r, iCode),
            objective: at(r, iObj).replaceAll(RegExp(r'\s+'), ' '),
            address: at(r, iAddr).replaceAll(RegExp(r'\s+'), ' '),
            district: at(r, iDist),
            province: at(r, iProv),
          ),
    ];
  }

  static List<List<String>> _csvRows(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        row.add(field.toString());
        field.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  // ---------- โหลดและเก็บในเครื่อง ----------

  static Future<File> _fileFor(int year, int month) async {
    final dir = await cacheDirectory();
    return File('${dir.path}/99_$year${month.toString().padLeft(2, '0')}_1.csv');
  }

  /// เดือนที่โหลดเก็บไว้แล้ว ใหม่ → เก่า
  static Future<List<(int, int)>> cachedMonths() async {
    final dir = await cacheDirectory();
    if (!await dir.exists()) return const [];
    final months = <(int, int)>[];
    await for (final f in dir.list()) {
      final m = RegExp(r'99_(\d{4})(\d{2})_1\.csv$').firstMatch(f.path);
      if (m != null) months.add((int.parse(m.group(1)!), int.parse(m.group(2)!)));
    }
    months.sort((a, b) => (b.$1 * 12 + b.$2).compareTo(a.$1 * 12 + a.$2));
    return months;
  }

  /// เปิดข้อมูลเดือนที่เก็บไว้ในเครื่อง (null = ยังไม่เคยโหลด)
  static Future<DbdMonthData?> loadCached(int year, int month) async {
    final file = await _fileFor(year, month);
    if (!await file.exists()) return null;
    final text = await file.readAsString();
    return DbdMonthData(
      year: year,
      month: month,
      companies: await compute(parseCsv, text),
      downloadedAt: await file.lastModified(),
    );
  }

  /// โหลดเดือนนั้นจาก DBD แล้วเก็บทับของเดิม — null = DBD ยังไม่ออกไฟล์ของเดือนนั้น
  static Future<DbdMonthData?> download(int year, int month) async {
    final client = clientFactory();
    try {
      final res = await client.get(uriFor(year, month)).timeout(const Duration(seconds: 60));
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) throw HttpException('DBD ตอบกลับ ${res.statusCode}');
      final text = utf8.decode(res.bodyBytes, allowMalformed: true);
      final companies = await compute(parseCsv, text);
      // หน้าแจ้งข้อผิดพลาด/ไฟล์ว่างที่ตอบ 200 — ไม่เก็บทับข้อมูลดีที่มีอยู่
      if (companies.isEmpty) return null;

      final file = await _fileFor(year, month);
      await file.parent.create(recursive: true);
      await file.writeAsString(text, flush: true);
      return DbdMonthData(year: year, month: month, companies: companies, downloadedAt: DateTime.now());
    } finally {
      client.close();
    }
  }

  /// หาเดือนล่าสุดที่ DBD ออกไฟล์แล้ว (ไล่ย้อนจากเดือนนี้ไม่เกิน [lookBack] เดือน) แล้วโหลดเก็บไว้
  /// DBD มักออกไฟล์ของเดือนก่อนในช่วงต้นเดือนถัดไป
  static Future<DbdMonthData?> downloadLatest({DateTime? now, int lookBack = 4}) async {
    final today = now ?? DateTime.now();
    for (var i = 0; i < lookBack; i++) {
      final d = DateTime(today.year, today.month - i);
      final data = await download(d.year, d.month);
      if (data != null) return data;
    }
    return null;
  }

  /// ผู้มุ่งหวังจากบริษัทตั้งใหม่ — ติดทุนและที่ตั้งไว้ในรายละเอียด จะได้รู้ว่าเลือกมาเพราะอะไร
  static Client toClient(DbdCompany c, {DateTime? now}) {
    final clean = c.name.replaceFirst(RegExp(r'^(บมจ|บจ|หจ|หส)\.\s*'), '').trim();
    return Client(
      id: newId(),
      name: c.name,
      initials: clean.isEmpty ? '?' : clean.characters.take(2).toString(),
      policyLabel: 'บริษัทตั้งใหม่ ทุน ${formatCapital(c.capital)} • ${c.provinceName}',
      stage: ClientStage.newLead,
      source: ClientSource.dbdNewCompany,
      createdAt: now ?? DateTime.now(),
    );
  }

  /// ทุนแบบอ่านง่าย: 10,000,000 → "10 ล้าน", 500,000 → "500,000 บาท"
  static String formatCapital(double v) {
    String group(String digits) => digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    if (v >= 1000000) {
      final m = v / 1000000;
      return m == m.roundToDouble() ? '${group(m.toStringAsFixed(0))} ล้าน' : '${m.toStringAsFixed(1)} ล้าน';
    }
    return '${group(v.toStringAsFixed(0))} บาท';
  }
}
