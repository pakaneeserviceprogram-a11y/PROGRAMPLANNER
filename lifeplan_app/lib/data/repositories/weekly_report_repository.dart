import 'package:hive_flutter/hive_flutter.dart';

import '../../models/weekly_report.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';

class WeeklyReportRepository extends HiveRepository<WeeklyReport> {
  WeeklyReportRepository()
      : super(
          box: Hive.box<Map>(HiveBoxes.weeklyReports),
          fromMap: WeeklyReport.fromMap,
          toMap: (r) => r.toMap(),
          idOf: (r) => r.id,
        );

  /// รายงานของสัปดาห์ที่วันนั้นอยู่ — ยังไม่เคยบันทึก = รายงานเปล่าของสัปดาห์นั้น
  WeeklyReport getForWeek(DateTime day) {
    final map = box.get(WeeklyReport.weekKeyOf(day));
    if (map == null) return WeeklyReport(weekStart: day);
    return WeeklyReport.fromMap(Map<String, dynamic>.from(map));
  }

  WeeklyReport getThisWeek() => getForWeek(DateTime.now());

  /// รายงานที่บันทึกไว้จริง เรียงสัปดาห์ล่าสุดขึ้นก่อน
  List<WeeklyReport> getAllSorted() =>
      getAll()..sort((a, b) => b.weekStart.compareTo(a.weekStart));
}
