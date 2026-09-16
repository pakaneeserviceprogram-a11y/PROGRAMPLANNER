import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifeplan_app/models/life_category.dart';
import 'package:lifeplan_app/models/schedule_event.dart';
import 'package:lifeplan_app/widgets/reminder_popup.dart';

const _event = ScheduleEvent(
  id: 'e1',
  time: '09:00',
  weekday: DateTime.wednesday,
  title: 'ประชุมทีมงานประจำ',
  subtitle: 'ห้องประชุม A',
  category: LifeCategory.work,
);

/// เปิดป๊อปอัปขึ้นมา แล้วคืน list ที่จะได้ค่าที่ผู้ใช้เลือกเมื่อป๊อปอัปถูกปิด
/// (true = กดเลื่อนเตือน, false = กดรับทราบ)
Future<List<bool>> _openPopup(WidgetTester tester, {int minutesBefore = 0}) async {
  final answers = <bool>[];
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async =>
            answers.add(await ReminderPopup.show(context, _event, minutesBefore: minutesBefore)),
        child: const Text('เปิด'),
      ),
    ),
  ));
  await tester.tap(find.text('เปิด'));
  await tester.pumpAndSettle();
  return answers;
}

void main() {
  testWidgets('ป๊อปอัปแสดงชื่อ เวลา และหมวดของกิจกรรม', (tester) async {
    await _openPopup(tester);

    expect(find.text('ประชุมทีมงานประจำ'), findsOneWidget);
    expect(find.text('ห้องประชุม A'), findsOneWidget);
    expect(find.text('วันพุธ 09:00 น.'), findsOneWidget);
    expect(find.text('ถึงเวลาแล้ว'), findsOneWidget);
    expect(find.text('งานประจำ'), findsOneWidget);

    await tester.tap(find.text('รับทราบ'));
    await tester.pumpAndSettle();
  });

  testWidgets('เตือนล่วงหน้าจะบอกว่าเหลืออีกกี่นาที', (tester) async {
    await _openPopup(tester, minutesBefore: 10);
    expect(find.text('อีก 10 นาทีจะถึงเวลา'), findsOneWidget);

    await tester.tap(find.text('รับทราบ'));
    await tester.pumpAndSettle();
  });

  testWidgets('แตะนอกกรอบไม่ปิดป๊อปอัป ต้องกดปุ่มเอง', (tester) async {
    final answers = await _openPopup(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('ประชุมทีมงานประจำ'), findsOneWidget);
    expect(answers, isEmpty);

    await tester.tap(find.text('รับทราบ'));
    await tester.pumpAndSettle();
    expect(find.text('ประชุมทีมงานประจำ'), findsNothing);
    expect(answers, [false]);
  });

  testWidgets('กดเลื่อนเตือนคืนค่า true ให้ผู้เรียกไปตั้งเตือนซ้ำ', (tester) async {
    final answers = await _openPopup(tester);

    await tester.tap(find.text('เตือนอีกใน $snoozeMinutes นาที'));
    await tester.pumpAndSettle();

    expect(find.text('ประชุมทีมงานประจำ'), findsNothing);
    expect(answers, [true]);
  });
}
