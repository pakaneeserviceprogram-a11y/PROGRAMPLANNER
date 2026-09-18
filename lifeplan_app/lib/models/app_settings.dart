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

  /// เตือนให้ดื่มน้ำเป็นช่วง ๆ ระหว่างวัน
  ///
  /// ไม่ได้เก็บเป็นกิจกรรมในตารางเวลาเหมือนมื้ออาหาร เพราะเตือนทุก 2 ชม.
  /// จะกลายเป็น 42 รายการต่อสัปดาห์จนตารางรก — ตั้งเป็นการแจ้งเตือนรายวันตรง ๆ แทน
  final bool waterRemindersEnabled;

  /// เตือนทุกกี่ชั่วโมง (2 = 09:00, 11:00, ... )
  final int waterIntervalHours;

  /// ช่วงเวลาที่ยอมให้เตือน (ชั่วโมงเต็ม) — นอกช่วงนี้ไม่เตือน เช่น ตอนนอน
  final int waterStartHour;
  final int waterEndHour;

  /// ผู้ใช้ล้างข้อมูลเพื่อเริ่มเก็บประวัติใหม่แล้ว — ห้าม `SeedData` ใส่ข้อมูล
  /// ตัวอย่างกลับเข้ามาอีกตอนเปิดแอปครั้งถัดไป (ไม่งั้นจะเห็นข้อมูลปลอมโผล่ซ้ำ)
  final bool sampleDataDisabled;

  const AppSettings({
    this.scheduleRemindersEnabled = false,
    this.remindMinutesBefore = 10,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.popupEnabled = true,
    this.waterRemindersEnabled = false,
    this.waterIntervalHours = 2,
    this.waterStartHour = 9,
    this.waterEndHour = 20,
    this.sampleDataDisabled = false,
  });

  AppSettings copyWith({
    bool? scheduleRemindersEnabled,
    int? remindMinutesBefore,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? popupEnabled,
    bool? waterRemindersEnabled,
    int? waterIntervalHours,
    int? waterStartHour,
    int? waterEndHour,
    bool? sampleDataDisabled,
  }) =>
      AppSettings(
        scheduleRemindersEnabled: scheduleRemindersEnabled ?? this.scheduleRemindersEnabled,
        remindMinutesBefore: remindMinutesBefore ?? this.remindMinutesBefore,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        popupEnabled: popupEnabled ?? this.popupEnabled,
        waterRemindersEnabled: waterRemindersEnabled ?? this.waterRemindersEnabled,
        waterIntervalHours: waterIntervalHours ?? this.waterIntervalHours,
        waterStartHour: waterStartHour ?? this.waterStartHour,
        waterEndHour: waterEndHour ?? this.waterEndHour,
        sampleDataDisabled: sampleDataDisabled ?? this.sampleDataDisabled,
      );

  /// เวลาที่จะเตือนดื่มน้ำในหนึ่งวัน เช่น ["09:00", "11:00", ...] (ว่าง = ไม่ต้องเตือน)
  List<String> get waterReminderTimes {
    if (!waterRemindersEnabled || waterIntervalHours <= 0 || waterEndHour < waterStartHour) {
      return const [];
    }
    return [
      for (var h = waterStartHour; h <= waterEndHour; h += waterIntervalHours)
        '${h.toString().padLeft(2, '0')}:00',
    ];
  }

  Map<String, dynamic> toMap() => {
        'scheduleRemindersEnabled': scheduleRemindersEnabled,
        'remindMinutesBefore': remindMinutesBefore,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'popupEnabled': popupEnabled,
        'waterRemindersEnabled': waterRemindersEnabled,
        'waterIntervalHours': waterIntervalHours,
        'waterStartHour': waterStartHour,
        'waterEndHour': waterEndHour,
        'sampleDataDisabled': sampleDataDisabled,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        scheduleRemindersEnabled: map['scheduleRemindersEnabled'] as bool? ?? false,
        remindMinutesBefore: map['remindMinutesBefore'] as int? ?? 10,
        // ค่าที่บันทึกไว้ก่อนมีเสียง/ป๊อปอัปยังไม่มีคีย์เหล่านี้ — ให้เปิดไว้เป็นค่าเริ่มต้น
        soundEnabled: map['soundEnabled'] as bool? ?? true,
        vibrationEnabled: map['vibrationEnabled'] as bool? ?? true,
        popupEnabled: map['popupEnabled'] as bool? ?? true,
        // ค่าที่บันทึกไว้ก่อนมีเตือนดื่มน้ำยังไม่มีคีย์เหล่านี้
        waterRemindersEnabled: map['waterRemindersEnabled'] as bool? ?? false,
        waterIntervalHours: (map['waterIntervalHours'] as num?)?.toInt() ?? 2,
        waterStartHour: (map['waterStartHour'] as num?)?.toInt() ?? 9,
        waterEndHour: (map['waterEndHour'] as num?)?.toInt() ?? 20,
        sampleDataDisabled: map['sampleDataDisabled'] as bool? ?? false,
      );
}
