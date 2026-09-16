/// ตั้งค่าทั่วไปของแอปที่ผู้ใช้ปรับได้ (การแจ้งเตือน + สถานะข้อมูลตัวอย่าง)
class AppSettings {
  final bool scheduleRemindersEnabled;

  /// เตือนล่วงหน้ากี่นาทีก่อนถึงเวลากิจกรรม (0 = ตรงเวลา)
  final int remindMinutesBefore;

  /// เล่นเสียงเตือนตอนแจ้งเตือนเด้ง
  final bool soundEnabled;

  /// สั่นตอนแจ้งเตือนเด้ง
  final bool vibrationEnabled;

  /// เด้งป๊อปอัปกลางจอตอนเปิดแอปอยู่ (นอกเหนือจากการแจ้งเตือนของระบบ)
  final bool popupEnabled;

  /// ผู้ใช้ล้างข้อมูลเพื่อเริ่มเก็บประวัติใหม่แล้ว — ห้าม `SeedData` ใส่ข้อมูล
  /// ตัวอย่างกลับเข้ามาอีกตอนเปิดแอปครั้งถัดไป (ไม่งั้นจะเห็นข้อมูลปลอมโผล่ซ้ำ)
  final bool sampleDataDisabled;

  const AppSettings({
    this.scheduleRemindersEnabled = false,
    this.remindMinutesBefore = 10,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.popupEnabled = true,
    this.sampleDataDisabled = false,
  });

  AppSettings copyWith({
    bool? scheduleRemindersEnabled,
    int? remindMinutesBefore,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? popupEnabled,
    bool? sampleDataDisabled,
  }) =>
      AppSettings(
        scheduleRemindersEnabled: scheduleRemindersEnabled ?? this.scheduleRemindersEnabled,
        remindMinutesBefore: remindMinutesBefore ?? this.remindMinutesBefore,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        popupEnabled: popupEnabled ?? this.popupEnabled,
        sampleDataDisabled: sampleDataDisabled ?? this.sampleDataDisabled,
      );

  Map<String, dynamic> toMap() => {
        'scheduleRemindersEnabled': scheduleRemindersEnabled,
        'remindMinutesBefore': remindMinutesBefore,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'popupEnabled': popupEnabled,
        'sampleDataDisabled': sampleDataDisabled,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        scheduleRemindersEnabled: map['scheduleRemindersEnabled'] as bool? ?? false,
        remindMinutesBefore: map['remindMinutesBefore'] as int? ?? 10,
        // ค่าที่บันทึกไว้ก่อนมีเสียง/ป๊อปอัปยังไม่มีคีย์เหล่านี้ — ให้เปิดไว้เป็นค่าเริ่มต้น
        soundEnabled: map['soundEnabled'] as bool? ?? true,
        vibrationEnabled: map['vibrationEnabled'] as bool? ?? true,
        popupEnabled: map['popupEnabled'] as bool? ?? true,
        sampleDataDisabled: map['sampleDataDisabled'] as bool? ?? false,
      );
}
