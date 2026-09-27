import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/medication.dart';
import '../hive_boxes.dart';
import '../hive_repository.dart';

class MedicationRepository extends HiveRepository<Medication> {
  MedicationRepository()
      : super(
          box: Hive.box<Map>(HiveBoxes.medications),
          fromMap: Medication.fromMap,
          toMap: (m) => m.toMap(),
          idOf: (m) => m.id,
        );

  /// ยาที่ยังใช้อยู่ เรียงยารักษาโรคก่อนวิตามิน แล้วเรียงตามชื่อ
  ///
  /// ยารักษาโรคขึ้นก่อนเพราะลืมแล้วมีผลต่อการรักษามากกว่า
  List<Medication> getActive() {
    final items = getAll().where((m) => m.active).toList();
    items.sort((a, b) {
      if (a.kind != b.kind) return a.kind == MedicationKind.treatment ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  List<Medication> byKind(MedicationKind kind) => getActive().where((m) => m.kind == kind).toList();
}

/// บันทึกว่ากินยามื้อไหนไปแล้วบ้าง — เก็บเป็นวันละหนึ่งเรคคอร์ด
///
/// คีย์ของแต่ละครั้งคือ `<medId>@<HH:mm>` เพื่อให้ยาตัวเดียวกันหลายเวลาแยกกันได้
class MedicationLogRepository {
  Box<Map> get _box => Hive.box<Map>(HiveBoxes.medicationLog);

  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  static String doseKey(String medicationId, String time) => '$medicationId@$time';

  Set<String> takenOn(DateTime day) {
    final map = _box.get(dateKey(day));
    if (map == null) return {};
    return ((map['taken'] as List?) ?? const []).map((e) => '$e').toSet();
  }

  bool isTaken(DateTime day, String medicationId, String time) =>
      takenOn(day).contains(doseKey(medicationId, time));

  /// ติ๊ก/ยกเลิกว่ากินแล้ว — คืนสถานะใหม่หลังกด
  Future<bool> toggle(DateTime day, String medicationId, String time) async {
    final key = doseKey(medicationId, time);
    final taken = takenOn(day);
    final nowTaken = !taken.remove(key);
    if (nowTaken) taken.add(key);
    await _box.put(dateKey(day), {'date': dateKey(day), 'taken': taken.toList()});
    return nowTaken;
  }

  ValueListenable<Box<Map>> listenable() => _box.listenable();
}
