import '../models/sleep_entry.dart';
import 'repositories/sleep_repository.dart';

/// หนึ่งช่องของกราฟย้อนหลัง — คืนที่ยังไม่ได้บันทึกก็ยังมีช่องของตัวเอง
/// (ไม่งั้นกราฟจะบีบวันที่ขาดหายจนดูเหมือนนอนต่อเนื่องทุกคืน)
class SleepNight {
  /// วันที่ตื่น (คีย์เดียวกับ `SleepEntry.date`)
  final DateTime date;
  final SleepEntry? entry;

  const SleepNight({required this.date, this.entry});

  bool get isLogged => entry != null;
  int get durationMinutes => entry?.durationMinutes ?? 0;
}

/// ประวัติการนอนย้อนหลังหลายคืน (เก่า → ใหม่ คืนล่าสุดอยู่ท้าย)
class SleepHistory {
  final List<SleepNight> nights;

  const SleepHistory(this.nights);

  factory SleepHistory.of(SleepRepository repo, {int days = 30, DateTime? until}) {
    final end = until ?? DateTime.now();
    return SleepHistory([
      for (var i = days - 1; i >= 0; i--)
        () {
          // ลบวันแบบปฏิทิน ไม่ใช้ Duration — กันคลาดในวันเปลี่ยนเวลาออมแสง
          final day = DateTime(end.year, end.month, end.day - i);
          return SleepNight(date: day, entry: repo.getForDay(day));
        }(),
    ]);
  }

  List<SleepEntry> get loggedNights => [for (final n in nights) if (n.entry != null) n.entry!];

  int get loggedCount => loggedNights.length;

  SleepStats get stats => SleepStats.of(loggedNights);

  /// คืนที่นอนได้ถึงเป้า (นับเฉพาะคืนที่บันทึกไว้)
  int nightsMeetingTarget(int targetMinutes) =>
      loggedNights.where((n) => n.durationMinutes >= targetMinutes).length;

  int get maxMinutes => nights.fold<int>(0, (a, n) => n.durationMinutes > a ? n.durationMinutes : a);

  /// ค่าเฉลี่ยรายสัปดาห์จากคืนล่าสุดย้อนกลับไป (เก่า → ใหม่) — สัปดาห์ที่ไม่มีบันทึกเลยได้ null
  ///
  /// ใช้ดูแนวโน้มว่าดีขึ้นหรือแย่ลง โดยไม่ต้องเพ่งกราฟรายคืน
  List<double?> weeklyAverages() {
    final result = <double?>[];
    for (var start = nights.length - 7; start > -7; start -= 7) {
      final chunk = nights.sublist(start < 0 ? 0 : start, start + 7 > nights.length ? nights.length : start + 7);
      final logged = chunk.where((n) => n.isLogged).toList();
      result.insert(
        0,
        logged.isEmpty ? null : logged.fold<int>(0, (s, n) => s + n.durationMinutes) / logged.length,
      );
    }
    return result;
  }
}
