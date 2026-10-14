import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lifeplan_app/data/dbd_open_data.dart';
import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/repositories/client_repository.dart';
import 'package:lifeplan_app/models/client.dart';
import 'package:lifeplan_app/screens/dbd_new_companies_screen.dart';

/// ไฟล์ตัวอย่างหน้าตาเหมือนไฟล์จริงของ DBD: มี BOM, ช่องที่มีจุลภาคอยู่ในเครื่องหมายคำพูด, แถวว่างทั้งแถว
const _csv = '﻿เลขทะเบียน,ชื่อนิติบุคคล,วันที่จดทะเบียน,ทุนจดทะเบียน,รหัสวัตถุประสงค์,วัตถุประสงค์,ที่ตั้งสำนักงานใหญ่,ตำบล,อำเภอ,จังหวัด,รหัสไปรษณีย์\n'
    '0105569000001,บจ.ก่อสร้างใหญ่ จำกัด,2569-09-01,50000000,41001,ก่อสร้างอาคาร,1 ถ.สุขุมวิท,แขวงคลองตัน,เขตคลองเตย,กรุงเทพมหานคร,10110\n'
    ',,,,,,,,,,\n'
    '0205569000002,บจ.ร้านอาหารดี จำกัด,2569-09-02,1000000,56101,"ร้านอาหาร, เครื่องดื่ม",2 ม.1,ต.บางแสน,อ.เมืองชลบุรี,จ.ชลบุรี,20130\n'
    '0203569000003,หจ.ขนส่งเร็ว,2569-09-03,5000000,49231,ขนส่งสินค้าทางถนน,3 ม.2,ต.หนองปรือ,อ.บางละมุง,จ.ชลบุรี,20150\n'
    '0107569000004,บมจ.มหาชนตัวอย่าง,2569-09-04,900000000,64201,"ลงทุน ""ถือหุ้น"" ในบริษัทอื่น",4 ถ.สีลม,แขวงสีลม,เขตบางรัก,กรุงเทพมหานคร,10500\n';

void main() {
  group('parseCsv', () {
    test('อ่านช่องที่มีจุลภาค/เครื่องหมายคำพูด ข้าม BOM และแถวว่าง', () {
      final list = DbdOpenData.parseCsv(_csv);
      expect(list, hasLength(4));
      final food = list.firstWhere((c) => c.regNo == '0205569000002');
      expect(food.objective, 'ร้านอาหาร, เครื่องดื่ม');
      expect(food.capital, 1000000);
      expect(food.provinceName, 'ชลบุรี');
      expect(food.kind, 'บจ');
      expect(list.firstWhere((c) => c.kind == 'บมจ').objective, 'ลงทุน "ถือหุ้น" ในบริษัทอื่น');
      expect(list.firstWhere((c) => c.regNo.startsWith('0105')).provinceName, 'กรุงเทพมหานคร');
    });

    test('ไฟล์เปลี่ยนรูปแบบ (ไม่มีคอลัมน์ที่ต้องใช้) แจ้งชัดเจน ไม่เดา', () {
      expect(() => DbdOpenData.parseCsv('a,b,c\n1,2,3\n'), throwsFormatException);
    });
  });

  group('DbdFilter', () {
    final all = DbdOpenData.parseCsv(_csv);

    test('เรียงตามทุนมาก → น้อย และกรองทุนขั้นต่ำ', () {
      expect(const DbdFilter().apply(all).map((c) => c.capital), [900000000, 50000000, 5000000, 1000000]);
      expect(const DbdFilter(minCapital: 5000000).apply(all), hasLength(3));
    });

    test('กรองจังหวัด ประเภท และคำค้นในประเภทธุรกิจ', () {
      expect(const DbdFilter(province: 'ชลบุรี').apply(all), hasLength(2));
      expect(const DbdFilter(kind: 'หจ').apply(all).single.name, 'หจ.ขนส่งเร็ว');
      expect(const DbdFilter(keyword: 'ขนส่ง').apply(all).single.regNo, '0203569000003');
      expect(const DbdFilter(keyword: 'ร้านอาหาร เมืองชลบุรี').apply(all), hasLength(1), reason: 'ค้นอำเภอได้');
    });
  });

  test('แสดงทุนแบบอ่านง่าย', () {
    expect(DbdOpenData.formatCapital(10000000), '10 ล้าน');
    expect(DbdOpenData.formatCapital(2500000), '2.5 ล้าน');
    expect(DbdOpenData.formatCapital(500000), '500,000 บาท');
    expect(DbdOpenData.formatCapital(4042000000), '4,042 ล้าน');
  });

  test('เพิ่มเป็นผู้มุ่งหวังพร้อมทุน จังหวัด และแหล่งที่มา DBD', () {
    final c = DbdOpenData.parseCsv(_csv).firstWhere((c) => c.kind == 'หจ');
    final client = DbdOpenData.toClient(c, now: DateTime(2026, 10, 14));
    expect(client.name, 'หจ.ขนส่งเร็ว');
    expect(client.initials, 'ขน');
    expect(client.source, ClientSource.dbdNewCompany);
    expect(client.policyLabel, 'บริษัทตั้งใหม่ ทุน 5 ล้าน • ชลบุรี');
    expect(client.createdAt, DateTime(2026, 10, 14));
  });

  group('โหลดและเก็บในเครื่อง', () {
    late Directory tmp;
    final requested = <Uri>[];

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('dbd_test');
      requested.clear();
      DbdOpenData.cacheDirectory = () async => Directory('${tmp.path}/dbd');
      // DBD มีไฟล์ถึงเดือน ก.ย. 2026 เท่านั้น
      DbdOpenData.clientFactory = () => MockClient((req) async {
            requested.add(req.url);
            return req.url.path.endsWith('99_202609_1.csv')
                ? http.Response.bytes(utf8.encode(_csv), 200)
                : http.Response('not found', 404);
          });
    });

    tearDown(() async => tmp.delete(recursive: true));

    test('URL ตามรูปแบบไฟล์ของ DBD', () {
      expect(DbdOpenData.uriFor(2026, 9).toString(),
          'https://openapi.dbd.go.th/juristic_person/registration/99_202609_1.csv');
    });

    test('อัปเดต: เดือนนี้ยังไม่ออก ย้อนไปเดือนก่อนจนเจอ แล้วเก็บไว้ในเครื่อง', () async {
      final data = await DbdOpenData.downloadLatest(now: DateTime(2026, 10, 14));
      expect(data!.year, 2026);
      expect(data.month, 9);
      expect(data.companies, hasLength(4));
      expect(requested.map((u) => u.pathSegments.last), ['99_202610_1.csv', '99_202609_1.csv']);

      expect(await DbdOpenData.cachedMonths(), [(2026, 9)]);
      final cached = await DbdOpenData.loadCached(2026, 9);
      expect(cached!.companies, hasLength(4));
      expect(await DbdOpenData.loadCached(2026, 8), isNull);
    });

    test('เดือนที่ DBD ยังไม่ออกไฟล์ คืน null และไม่สร้างไฟล์เปล่า', () async {
      expect(await DbdOpenData.download(2026, 11), isNull);
      expect(await DbdOpenData.cachedMonths(), isEmpty);
    });

    group('หน้าจอ', () {
      setUp(() async {
        await setUpTestHive();
        await Hive.openBox<Map>(HiveBoxes.clients, bytes: Uint8List(0));
      });
      tearDown(() async {
        await Hive.close();
        await tearDownTestHive();
      });

      // งานไฟล์/isolate จริงไม่เดินใน fake async — รอทีละนิดจนข้อความที่ต้องการขึ้น
      // (pumpAndSettle ใช้ไม่ได้ระหว่างโหลด เพราะวงกลมหมุนไม่มีวันหยุด)
      Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
        for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump();
        }
        expect(finder, findsOneWidget);
      }

      testWidgets('ยังไม่มีข้อมูล → กดอัปเดต → กรองทุน → เพิ่มเป็นผู้มุ่งหวัง', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: DbdNewCompaniesScreen()));
        await pumpUntil(tester, find.text('ยังไม่มีข้อมูลในเครื่อง'));

        await tester.tap(find.byKey(const ValueKey('dbd-update')));
        await pumpUntil(tester, find.text('พบ 4 ราย • เรียงตามทุนจดทะเบียน มาก → น้อย'));
        await tester.pump(const Duration(seconds: 5)); // ให้ snackbar "อัปเดตแล้ว" หายก่อน
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('dbd-capital-10000000')));
        await tester.pumpAndSettle();
        expect(find.text('พบ 2 ราย • เรียงตามทุนจดทะเบียน มาก → น้อย'), findsOneWidget);
        // อันดับ 1 = ทุนสูงสุด
        await tester.tap(find.text('บมจ.มหาชนตัวอย่าง'));
        await tester.pumpAndSettle();
        expect(find.text('อันดับ 1 ตามทุนจดทะเบียน'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('dbd-add-prospect')));
        await tester.pumpAndSettle();
        expect(ClientRepository().getAll().single.source, ClientSource.dbdNewCompany);
        expect(find.text('อยู่ในรายชื่อลูกค้าแล้ว'), findsOneWidget);
      });
    });
  });
}
