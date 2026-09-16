import 'package:flutter_test/flutter_test.dart';

import 'package:lifeplan_app/data/calendar_utils.dart';

void main() {
  test('monthGrid starts on Monday and ends on Sunday covering the whole month', () {
    // กันยายน 2026: วันที่ 1 เป็นวันอังคาร วันที่ 30 เป็นวันพุธ
    final days = CalendarUtils.monthGrid(2026, 9);
    expect(days.first, DateTime(2026, 8, 31));
    expect(days.last, DateTime(2026, 10, 4));
    expect(days.length, 35);
    expect(days.where((d) => d.month == 9), hasLength(30));
    expect(days.first.weekday, DateTime.monday);
    expect(days.last.weekday, DateTime.sunday);
  });

  test('monthGrid handles February and months needing six rows', () {
    // กุมภาพันธ์ 2027 เริ่มวันจันทร์ จบวันอาทิตย์พอดี → 4 แถว
    expect(CalendarUtils.monthGrid(2027, 2), hasLength(28));
    // พฤศจิกายน 2026 เริ่มวันอาทิตย์ → ต้องมี 6 แถว
    expect(CalendarUtils.monthGrid(2026, 11), hasLength(42));
    expect(CalendarUtils.daysInMonth(2028, 2), 29);
    expect(CalendarUtils.daysInMonth(2026, 2), 28);
  });

  test('week and month arithmetic crosses month/year boundaries', () {
    expect(CalendarUtils.startOfWeek(DateTime(2027, 1, 2)), DateTime(2026, 12, 28));
    expect(CalendarUtils.addDays(DateTime(2026, 12, 30), 7), DateTime(2027, 1, 6));
    expect(CalendarUtils.addMonths(DateTime(2026, 12), 1), DateTime(2027, 1));
    expect(CalendarUtils.addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
  });

  test('Thai labels use the Buddhist year', () {
    expect(CalendarUtils.thaiDate(DateTime(2026, 9, 16)), '16 กันยายน 2569');
    expect(CalendarUtils.thaiMonthYear(DateTime(2026, 9)), 'กันยายน 2569');
  });
}
