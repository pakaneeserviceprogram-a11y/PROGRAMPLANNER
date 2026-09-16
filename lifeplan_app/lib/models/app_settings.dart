/// ตั้งค่าทั่วไปของแอปที่ผู้ใช้ปรับได้ (การแจ้งเตือน + สถานะข้อมูลตัวอย่าง)
class AppSettings {
  final bool scheduleRemindersEnabled;

  /// เตือนล่วงหน้ากี่นาทีก่อนถึงเวลากิจกรรม (0 = ตรงเวลา)
  final int remindMinutesBefore;

  /// ผู้ใช้ล้างข้อมูลเพื่อเริ่มเก็บประวัติใหม่แล้ว — ห้าม `SeedData` ใส่ข้อมูล
  /// ตัวอย่างกลับเข้ามาอีกตอนเปิดแอปครั้งถัดไป (ไม่งั้นจะเห็นข้อมูลปลอมโผล่ซ้ำ)
  final bool sampleDataDisabled;

  const AppSettings({
    this.scheduleRemindersEnabled = false,
    this.remindMinutesBefore = 10,
    this.sampleDataDisabled = false,
  });

  AppSettings copyWith({
    bool? scheduleRemindersEnabled,
    int? remindMinutesBefore,
    bool? sampleDataDisabled,
  }) =>
      AppSettings(
        scheduleRemindersEnabled: scheduleRemindersEnabled ?? this.scheduleRemindersEnabled,
        remindMinutesBefore: remindMinutesBefore ?? this.remindMinutesBefore,
        sampleDataDisabled: sampleDataDisabled ?? this.sampleDataDisabled,
      );

  Map<String, dynamic> toMap() => {
        'scheduleRemindersEnabled': scheduleRemindersEnabled,
        'remindMinutesBefore': remindMinutesBefore,
        'sampleDataDisabled': sampleDataDisabled,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        scheduleRemindersEnabled: map['scheduleRemindersEnabled'] as bool? ?? false,
        remindMinutesBefore: map['remindMinutesBefore'] as int? ?? 10,
        sampleDataDisabled: map['sampleDataDisabled'] as bool? ?? false,
      );
}
