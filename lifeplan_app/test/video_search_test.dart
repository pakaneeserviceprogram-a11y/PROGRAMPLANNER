import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:lifeplan_app/data/hive_boxes.dart';
import 'package:lifeplan_app/data/video_search.dart';
import 'package:lifeplan_app/screens/learning_screen.dart';
import 'package:lifeplan_app/screens/learning_videos_screen.dart';

/// ค้นคลิปความรู้บน YouTube — แอปไม่ได้ดึงรายชื่อคลิปเอง แต่ประกอบลิงก์ผลค้นหา
/// พร้อมพารามิเตอร์เรียงลำดับ แล้วให้ YouTube จัดอันดับให้
void main() {
  group('VideoSearch', () {
    test('ประกอบลิงก์ค้นหาพร้อมพารามิเตอร์เรียงตามยอดดู', () {
      final url = VideoSearch.searchUrl('วิเคราะห์หุ้น');

      expect(url.host, 'www.youtube.com');
      expect(url.path, '/results');
      expect(url.queryParameters['search_query'], 'วิเคราะห์หุ้น');
      expect(url.queryParameters['sp'], VideoSort.viewCount.filterParam);
      // ภาษาไทยต้องถูก encode ในลิงก์จริง ไม่ใช่ปล่อยดิบ ๆ
      expect(url.toString(), contains('%E0%B8'));
    });

    test('เลือกการเรียงแบบอื่นได้ และแต่ละแบบใช้ค่าไม่ซ้ำกัน', () {
      expect(
        VideoSearch.searchUrl('ออมเงิน', sort: VideoSort.uploadDate).queryParameters['sp'],
        VideoSort.uploadDate.filterParam,
      );

      final params = VideoSort.values.map((s) => s.filterParam).toSet();
      expect(params, hasLength(VideoSort.values.length));
      for (final sort in VideoSort.values) {
        expect(sort.label.trim(), isNotEmpty);
        expect(sort.hint.trim(), isNotEmpty);
      }
    });

    test('คำค้นว่างไม่ต้องใส่พารามิเตอร์เรียง และตัดช่องว่างหัวท้าย', () {
      final blank = VideoSearch.searchUrl('   ');
      expect(blank.queryParameters['search_query'], '');
      expect(blank.queryParameters.containsKey('sp'), isFalse);

      expect(VideoSearch.searchUrl('  ออมเงิน  ').queryParameters['search_query'], 'ออมเงิน');
    });

    test('หัวข้อแนะนำครอบคลุมเรื่องที่ตั้งใจไว้ และไม่มีคำค้นซ้ำ', () {
      final labels = VideoSearch.topics.map((t) => t.label).toList();
      expect(labels, containsAll(['การเงินส่วนบุคคล', 'การออม', 'วิเคราะห์หุ้น', 'ประกัน', 'สุขภาพ']));

      for (final topic in VideoSearch.topics) {
        expect(topic.queries, isNotEmpty, reason: topic.label);
        for (final q in topic.queries) {
          expect(q.trim(), isNotEmpty);
        }
      }
      final queries = VideoSearch.allQueries;
      expect(queries.toSet(), hasLength(queries.length));
    });
  });

  group('หน้าค้นคลิป', () {
    testWidgets('พิมพ์คำค้นแล้วกดปุ่ม เปิดลิงก์ YouTube ที่เรียงตามที่เลือก', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(MaterialApp(
        home: LearningVideosScreen(onOpenUrl: (url) async {
          opened.add(url);
          return true;
        }),
      ));

      await tester.enterText(find.byKey(const ValueKey('video-query-field')), 'วางแผนภาษี');
      await tester.pump();
      await tester.tap(find.text('ค้นบน YouTube'));
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect(opened.single.queryParameters['search_query'], 'วางแผนภาษี');
      expect(opened.single.queryParameters['sp'], VideoSort.viewCount.filterParam);
    });

    testWidgets('เปลี่ยนการเรียงเป็นใหม่ล่าสุดแล้วลิงก์เปลี่ยนตาม', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(MaterialApp(
        home: LearningVideosScreen(onOpenUrl: (url) async {
          opened.add(url);
          return true;
        }),
      ));

      await tester.tap(find.text('ยอดดูมากที่สุด').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ใหม่ล่าสุด').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('video-query-field')), 'ดอกเบี้ยทบต้น');
      await tester.pump();
      await tester.tap(find.text('ค้นบน YouTube'));
      await tester.pumpAndSettle();

      expect(opened.single.queryParameters['sp'], VideoSort.uploadDate.filterParam);
    });

    testWidgets('แตะคำค้นแนะนำเปิดได้เลยโดยไม่ต้องพิมพ์', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(MaterialApp(
        home: LearningVideosScreen(onOpenUrl: (url) async {
          opened.add(url);
          return true;
        }),
      ));

      const query = 'อ่านงบการเงินบริษัท';
      final chip = find.byKey(const ValueKey('query-chip-$query'));
      // ช่องกรอกข้อความมี Scrollable ของตัวเอง ต้องบอกว่าจะเลื่อนลิสต์ของหน้า
      await tester.scrollUntilVisible(chip, 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(opened.single.queryParameters['search_query'], query);
    });

    testWidgets('ยังไม่พิมพ์อะไรแล้วกดค้น ต้องบอกผู้ใช้แทนที่จะเปิดหน้าเปล่า', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(MaterialApp(
        home: LearningVideosScreen(onOpenUrl: (url) async {
          opened.add(url);
          return true;
        }),
      ));

      await tester.tap(find.text('ค้นบน YouTube'));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(find.textContaining('พิมพ์เรื่องที่อยากเรียน'), findsWidgets);
    });
  });

  group('หน้าเรียนรู้', () {
    setUp(() async {
      await setUpTestHive();
      await Future.wait([
        Hive.openBox<Map>(HiveBoxes.skillTracks, bytes: Uint8List(0)),
        Hive.openBox<Map>(HiveBoxes.learningStreak, bytes: Uint8List(0)),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      await tearDownTestHive();
    });

    testWidgets('มีทางเข้าหน้าค้นคลิป แตะแล้วเปิดหน้าใหม่', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LearningScreen()));
      await tester.pump();

      final entry = find.byKey(const ValueKey('open-video-search'));
      await tester.scrollUntilVisible(entry, 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.text('ค้นคลิปความรู้'), findsWidgets);
      expect(find.text('หัวข้อแนะนำ'), findsOneWidget);
    });
  });
}
