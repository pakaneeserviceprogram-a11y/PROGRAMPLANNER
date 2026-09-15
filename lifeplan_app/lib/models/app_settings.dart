/// ตั้งค่าทั่วไปของแอปที่ผู้ใช้ปรับได้ (ตอนนี้มีแค่เรื่องการแจ้งเตือน)
class AppSettings {
  final bool scheduleRemindersEnabled;

  /// เตือนล่วงหน้ากี่นาทีก่อนถึงเวลากิจกรรม (0 = ตรงเวลา)
  final int remindMinutesBefore;

  const AppSettings({
    this.scheduleRemindersEnabled = false,
    this.remindMinutesBefore = 10,
  });

  AppSettings copyWith({bool? scheduleRemindersEnabled, int? remindMinutesBefore}) => AppSettings(
        scheduleRemindersEnabled: scheduleRemindersEnabled ?? this.scheduleRemindersEnabled,
        remindMinutesBefore: remindMinutesBefore ?? this.remindMinutesBefore,
      );

  Map<String, dynamic> toMap() => {
        'scheduleRemindersEnabled': scheduleRemindersEnabled,
        'remindMinutesBefore': remindMinutesBefore,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        scheduleRemindersEnabled: map['scheduleRemindersEnabled'] as bool? ?? false,
        remindMinutesBefore: map['remindMinutesBefore'] as int? ?? 10,
      );
}
