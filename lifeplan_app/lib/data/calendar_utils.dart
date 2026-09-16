/// ตัวช่วยคำนวณปฏิทินรายเดือน/รายปีของหน้าตารางเวลา (สัปดาห์เริ่มวันจันทร์)
class CalendarUtils {
  CalendarUtils._();

  static const weekdayShort = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
  static const weekdayFull = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
  static const monthFull = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];
  static const monthShort = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// วันจันทร์ของสัปดาห์ที่มี [date]
  ///
  /// ใช้ DateTime(y, m, d - n) แทน subtract(Duration) เพราะ Duration นับเป็นชั่วโมง
  /// จะคลาดไป 1 ชม. ในวันที่เปลี่ยนเวลาออมแสง (เครื่องที่ตั้งโซนต่างประเทศ)
  static DateTime startOfWeek(DateTime date) => DateTime(date.year, date.month, date.day - (date.weekday - 1));

  /// บวก/ลบจำนวนวันแบบปฏิทิน (ไม่เพี้ยนตอนเปลี่ยนเวลาออมแสง)
  static DateTime addDays(DateTime date, int days) => DateTime(date.year, date.month, date.day + days);

  /// เดือนถัดไป/ก่อนหน้า (DateTime จัดการข้ามปีให้เอง เช่น เดือน 13 = มกราคมปีหน้า)
  static DateTime addMonths(DateTime month, int months) => DateTime(month.year, month.month + months);

  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// ช่องวันที่ของปฏิทินหนึ่งเดือน เริ่มวันจันทร์ก่อน/ตรงวันที่ 1 จนถึงวันอาทิตย์หลัง/ตรงวันสุดท้าย
  /// จึงมี 28, 35 หรือ 42 ช่องเสมอ (ช่องนอกเดือนใช้แสดงแบบจาง)
  static List<DateTime> monthGrid(int year, int month) {
    final first = startOfWeek(DateTime(year, month, 1));
    final last = DateTime(year, month, daysInMonth(year, month));
    final end = addDays(last, 7 - last.weekday);
    final days = <DateTime>[];
    for (var d = first; !d.isAfter(end); d = addDays(d, 1)) {
      days.add(d);
    }
    return days;
  }

  /// "16 กันยายน 2569" (พ.ศ.)
  static String thaiDate(DateTime d) => '${d.day} ${monthFull[d.month - 1]} ${d.year + 543}';

  /// "กันยายน 2569"
  static String thaiMonthYear(DateTime d) => '${monthFull[d.month - 1]} ${d.year + 543}';
}
