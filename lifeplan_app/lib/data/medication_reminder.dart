import '../models/medication.dart';
import 'repositories/medication_repository.dart';

/// ยาหนึ่งครั้งที่ต้องกินในวันนั้น
class MedicationDose {
  final Medication medication;

  /// "HH:mm"
  final String time;
  final bool taken;

  const MedicationDose({required this.medication, required this.time, this.taken = false});

  int get minutes {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  /// เลยเวลามาแล้วแต่ยังไม่ได้ติ๊ก
  bool isOverdue(DateTime now) => !taken && minutes < now.hour * 60 + now.minute;
}

/// รายการยาของวันนี้ + การตั้งแจ้งเตือน
///
/// **ไม่ลงในตารางเวลา** เหมือนมื้ออาหาร เพราะยา 3 มื้อ × 7 วัน = 21 รายการต่อยาหนึ่งตัว
/// ตารางจะรกจนใช้ไม่ได้ — ใช้การแจ้งเตือนรายวันตรง ๆ แทน (ดู `NotificationService`)
class MedicationReminder {
  MedicationReminder._();

  /// ทุกครั้งที่ต้องกินในวันหนึ่ง เรียงตามเวลา
  static List<MedicationDose> dosesFor(
    Iterable<Medication> medications,
    Set<String> takenKeys,
  ) {
    final doses = <MedicationDose>[];
    for (final med in medications) {
      if (!med.active) continue;
      for (final time in med.times) {
        doses.add(MedicationDose(
          medication: med,
          time: time,
          taken: takenKeys.contains(MedicationLogRepository.doseKey(med.id, time)),
        ));
      }
    }
    doses.sort((a, b) => a.minutes.compareTo(b.minutes));
    return doses;
  }

  /// ยาที่เลยเวลาแล้วยังไม่ได้ติ๊ก — เอาไว้เตือนบนหน้าหลัก
  static List<MedicationDose> overdue(List<MedicationDose> doses, {DateTime? now}) =>
      doses.where((d) => d.isOverdue(now ?? DateTime.now())).toList();

  /// ครั้งถัดไปที่ต้องกิน (ยังไม่ถึงเวลาและยังไม่ติ๊ก) — ไม่มีแล้ว = null
  static MedicationDose? next(List<MedicationDose> doses, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final minutes = current.hour * 60 + current.minute;
    for (final dose in doses) {
      if (!dose.taken && dose.minutes >= minutes) return dose;
    }
    return null;
  }

  /// ทุกคู่ (ยา, เวลา) ที่ต้องตั้งแจ้งเตือน เรียงคงที่เพื่อให้ id ของการแจ้งเตือนไม่สลับไปมา
  static List<({Medication medication, String time})> scheduleEntries(Iterable<Medication> medications) {
    final entries = <({Medication medication, String time})>[];
    for (final med in medications) {
      if (!med.active) continue;
      for (final time in med.times) {
        entries.add((medication: med, time: time));
      }
    }
    entries.sort((a, b) {
      final byId = a.medication.id.compareTo(b.medication.id);
      return byId != 0 ? byId : a.time.compareTo(b.time);
    });
    return entries;
  }

  /// ข้อความในการแจ้งเตือน — บอกขนาดและความสัมพันธ์กับมื้ออาหารเพราะเป็นสิ่งที่ลืมบ่อยที่สุด
  static String notificationBody(Medication med) {
    final parts = [med.dose, med.timing.label];
    if (med.kind == MedicationKind.treatment && (med.conditionLabel?.isNotEmpty ?? false)) {
      parts.add('สำหรับ${med.conditionLabel}');
    }
    return parts.join(' • ');
  }
}
