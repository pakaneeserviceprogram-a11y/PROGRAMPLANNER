# LifePlan — Handoff / เอกสารต่องาน

อัปเดตล่าสุด: 2026-09-16 (ป๊อปอัป+เสียงแจ้งเตือน และโมดูลคุณภาพการนอน) — ใช้ไฟล์นี้เพื่อกลับมาทำงานต่อได้เร็ว ไม่ต้องไล่อ่านทั้งบทสนทนาใหม่

ดูภาพรวมโปรเจกต์/ฟีเจอร์ที่ `README.md`, โครงสร้างข้อมูลที่ `DATA_MODEL.md` — ไฟล์นี้เน้นเฉพาะ "จะทำต่อยังไง"

---

## 0. สรุปงานรอบล่าสุด

### รอบ 2026-09-16 (ต่อ) — โมดูลคุณภาพการนอน

โมดูลที่ 7 ของแอป เข้าจากการ์ดเต็มความกว้างบนหน้าหลัก (`lib/screens/sleep_screen.dart`)

- **`SleepEntry`** (`lib/models/sleep_entry.dart`) — คืนละหนึ่งรายการ โดยใช้ **วันที่ตื่น** เป็น id (`yyyy-MM-dd`) แบบเดียวกับ `WaterLog` บันทึกซ้ำจึงทับของเดิมเสมอ
  - `durationMinutes` วนข้ามเที่ยงคืนด้วย `(wake - bed + 1440) % 1440` — อย่าลบตรง ๆ
  - `nightDate` = วันที่เข้านอน (เข้านอนตั้งแต่เที่ยงวันขึ้นไป = คืนของวันก่อนหน้า) ใช้แสดงว่า "คืนวันอังคาร"
  - `SleepStats.of()` สรุป 7 คืน: เวลานอน/คุณภาพ/การตื่นกลางดึกเฉลี่ย + **ความสม่ำเสมอของเวลาเข้านอน** + ปัจจัยรบกวนที่เจอบ่อย
  - **จุดที่พลาดง่าย**: เวลาเข้านอนหลังเที่ยงคืน (01:00) ต้อง +24 ชม. ก่อนหาค่าเฉลี่ย ไม่งั้น 23:00 กับ 01:00 จะถูกมองว่าห่างกัน 22 ชั่วโมงแทนที่จะเป็น 2 — มี test คุมไว้
- **`Insights.scoreOfNight()`** — เฉลี่ย 3 ส่วน: เวลานอน/เป้า, น้ำหนักคุณภาพที่ผู้ใช้ให้, และคะแนนการตื่นกลางดึก (ครั้งละ −15% พื้น 40%) และ `Insights.sleepScore()` ป้อนคะแนนเข้า `categoryScores()`
- **`LifeCategory.sleep`** ถูกเพิ่มเข้า enum (ระหว่าง `nutrition` กับ `work`) → หน้าตารางเวลาเลือกหมวดนี้ได้ทันที จึงตั้งเตือน "เตรียมตัวเข้านอน" แล้วได้ป๊อปอัป+เสียงจากรอบที่แล้วฟรี ๆ
  - เพิ่มค่าใน enum ปลอดภัยเพราะทุก `fromMap` ใช้ `firstWhere(..., orElse:)` และเก็บเป็นชื่อสตริง
- box ใหม่ `sleep_entries` — เพิ่มแล้วทั้งใน `HiveBoxes.init()`, `BackupService._boxNames` (อยู่ในไฟล์สำรอง) และ `recordBoxNames` (โดนล้างตอน "ล้างประวัติทั้งหมด")
  - **ข้อควรจำ**: เทสต์ทุกไฟล์ที่เปิด box เองต้องเพิ่ม `HiveBoxes.sleepEntries` ด้วย ไม่งั้น `Box not found` (แก้ `backup_test` / `repository_test` / `widget_test` / `dashboard_screen_test` ไปแล้ว)
- เป้าหมายใหม่ `GoalSettings.sleepTargetMinutes` (ค่าเริ่มต้น 480 = 8 ชม.) กรอกเป็น **ชั่วโมง** ในหน้าตั้งค่าเป้าหมาย แต่เก็บเป็นนาที
- `SleepScreen.tipsFor()` เป็น static ล้วน (รับ `SleepStats` + `GoalSettings`) จึงเทสต์คำแนะนำได้โดยไม่ต้อง pump หน้าจอ
- test ใหม่: `test/sleep_test.dart` + `test/sleep_screen_test.dart` — รวมชุดทดสอบเป็น **86 tests**
  - เทสต์ที่ใช้ memory box (`bytes: Uint8List(0)`) ต้อง `await Hive.close()` ก่อน `tearDownTestHive()` ไม่งั้นได้ `Unsupported operation ... for memory boxes`
  - รายการในหน้าจอถูกสร้างแบบ lazy ตามที่เลื่อนถึง — ต้อง `scrollUntilVisible` / `ensureVisible` ก่อน tap (ทั้งในหน้าและในบอตทอมชีต)

### รอบ 2026-09-16 (ต่อ) — ล้างข้อมูลเพื่อเริ่มเก็บประวัติใหม่

เพิ่มในหน้า `lib/screens/backup_screen.dart` (โปรไฟล์ → สำรอง & กู้คืนข้อมูล) ส่วนล่างสุด "เริ่มเก็บประวัติใหม่"

- `BackupService.clearRecords()` — ล้างเฉพาะ `recordBoxNames` (งาน, ออกกำลังกาย, มื้ออาหาร, น้ำดื่ม, ลูกค้า, รายงานสัปดาห์, การเงิน, การเรียนรู้, ตารางเวลา, สตรีค) คืนค่าจำนวนรายการที่ลบ — บัญชีผู้ใช้/เป้าหมาย/การตั้งค่ายังอยู่
- `BackupService.clearEverything()` — ล้างทุก box แล้วเด้งกลับหน้า Login (ยืนยัน 2 ชั้น)
- `BackupService.currentCounts()` — ใช้โชว์ในกล่องยืนยันว่ากำลังจะลบอะไรไปกี่รายการ
- **กันข้อมูลตัวอย่างกลับมา**: `AppSettings.sampleDataDisabled` ถูกตั้งเป็น true หลังล้างทุกครั้ง และ `SeedData.seedIfEmpty()` เช็คธงนี้เป็นอย่างแรกแล้ว return ทันที — ถ้าไม่มีธงนี้ ข้อมูลตัวอย่าง (ลูกค้าสมมติ ฯลฯ) จะโผล่กลับมาตอนเปิดแอปครั้งถัดไปเพราะ box ว่าง
  - `clearEverything()` ล้าง `app_settings` ไปด้วย จึงต้องเขียนธงกลับลงไป **หลัง** ล้างเสร็จ (ดู `_disableSampleData()`)
- หลังล้างต้องเรียก `NotificationService.syncScheduleReminders()` เพื่อยกเลิกการแจ้งเตือนของกิจกรรมที่ถูกลบไปแล้ว
- `flutter test` ผ่าน **46 tests** (เพิ่ม 4 เคสใน `test/backup_test.dart`)
- **ข้อควรจำ**: `seedIfEmpty()` อ่าน box `app_settings` แล้ว เทสต์ไหนที่เรียก `SeedData.seedIfEmpty()` ต้องเปิด box นี้ด้วย (แก้ `widget_test.dart` ไปแล้ว)

### รอบ 2026-09-16 (ต่อ) — รายงานผลงานประจำสัปดาห์ P-A-S-R-F-N-T ในโมดูลลูกค้า & ขายประกัน

ส่วนใหม่ในหน้า `lib/screens/crm_screen.dart` (คลาส `WeeklyReportSection` อยู่ท้ายไฟล์เดียวกัน) สำหรับสรุปงานขายรายสัปดาห์ส่งหัวหน้า

- **ข้อมูล**: `WeeklyReport` (`lib/models/weekly_report.dart`) — 1 รายการต่อ 1 สัปดาห์ คีย์ = `yyyy-MM-dd` ของวันจันทร์ (`WeeklyReport.weekKeyOf`) จึงบันทึกซ้ำทับสัปดาห์เดิมเสมอ เก็บ `ownerName`, `activities` (Map ของ `ActivityCode` → `WeeklyActivity{count, note}`) และ `salesPremium` → box ใหม่ `weekly_reports` (อยู่ในไฟล์สำรองแล้ว, `backupFormatVersion` ยังเป็น 1)
- **ตัวย่อ** `ActivityCode`: P=Prospect, A=Appointment, S=Sales, R=Referal, F=Follow, N=New Market, T=Team
- **ข้อความรายงาน** `WeeklyReport.toReportText()` ประกอบหัวเรื่อง + คำอธิบายตัวย่อ + บรรทัดของทุกตัวย่อ เช่น `A = 3 (ลูกค้าใหม่ 3)` และบรรทัด S พ่วงเบี้ยประกันให้เอง (`S = 2 ราย เบี้ยประมาณ 60,000 บาท (ขาย Offline)`) — ปุ่ม "คัดลอกส่งหัวหน้า" ยัดข้อความนี้ลงคลิปบอร์ด
- **วันที่แบบไทย** `WeeklyReport.thaiShortDate()` = `29/4/67` (พ.ศ. 2 หลักท้าย) ใช้ทั้งบนการ์ดและในข้อความ
- เลื่อนสัปดาห์ด้วยลูกศร ‹ › (ล็อกไม่ให้เลยสัปดาห์ปัจจุบัน) และปุ่ม "ย้อนหลัง" เปิด bottom sheet รายการรายงานที่บันทึกไว้ทั้งหมด
- `seed_data.dart` ใส่รายงานตัวอย่างของสัปดาห์ 29/4/67-5/5/67 ไว้ให้ตั้งแต่เปิดแอปครั้งแรก
- `flutter analyze` ไม่มีปัญหา, `flutter test` ผ่าน **42 tests** (เพิ่ม 2 unit test ใน `repository_test.dart` + `test/crm_screen_test.dart` 3 เคส)
- **ข้อควรจำ**: เพิ่ม box ใหม่แล้วต้องไปเปิด box นั้นใน `setUp` ของ `backup_test.dart`, `widget_test.dart`, `dashboard_screen_test.dart` ด้วย ไม่งั้นเทสต์เดิมพังเพราะ seed หา box ไม่เจอ
- **APK**: build แล้วที่ `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (18.8 MB) เซ็นด้วย release key จริง (SHA-256 `249a7ed3…`) และ bump `pubspec.yaml` เป็น `1.1.0+2` → ติดตั้งทับตัวก่อน (1.0.0+1) ได้โดยข้อมูลไม่หาย
- **กฎการอัปเดต APK**: ทุกครั้งที่จะแจก APK ใหม่ต้อง **bump build number ใน `pubspec.yaml`** (เลขหลัง `+`) ไม่งั้น Android ปฏิเสธการติดตั้งทับ — และต้องใช้ keystore เดิมเสมอ (`android/lifeplan-release.jks`) ห้ามปล่อยให้ fallback ไป debug key เพราะจะลงทับของเดิมไม่ได้

### รอบ 2026-09-16 — โมดูลทานอาหาร & โภชนาการ (บันทึกละเอียดที่ `16092026 โภชนาการ.md`)

โมดูลใหม่ทั้งชุด เข้าจากการ์ด "ทานอาหาร & โภชนาการ" ในหน้าหลัก (`lib/screens/nutrition_screen.dart`)

- **ข้อมูล**: `MealEntry` (มื้อ, เวลา, kcal, โปรตีน, แป้ง, ไขมัน, น้ำตาล, วิตามิน A–K, ก่อน/หลังออกกำลังกาย) + `WaterLog` (น้ำดื่มวันละ 1 รายการ คีย์ = `yyyy-MM-dd`, แก้วละ 250 มล.) → box ใหม่ `meal_entries`, `water_logs` (อยู่ในไฟล์สำรองแล้ว, `backupFormatVersion` ยังเป็น 1 เพราะไฟล์เก่าอ่านได้ตามเดิม)
- **เป้าหมาย**: `GoalSettings` เพิ่ม `calorieTarget`, `proteinTarget`, `carbTarget`, `fatTarget`, `sugarLimit`, `waterTargetMl` — แก้ได้ในหน้า ตั้งค่าเป้าหมาย (เรคคอร์ดเก่าที่ยังไม่มีฟิลด์เหล่านี้ใช้ค่าเริ่มต้นอัตโนมัติ)
- **หมวดชีวิตใหม่** `LifeCategory.nutrition` (สีชมพูแดง) — โผล่ในตารางเวลา, กราฟหน้า Progress และ `Insights.categoryScores()` ด้วย
- **คะแนนโภชนาการ** `Insights.nutritionScore()` = เฉลี่ยของ พลังงาน/เป้า, โปรตีน/เป้า, น้ำ/เป้า และคะแนนน้ำตาล (เกินเพดานยิ่งมากยิ่งลด)
- **เชื่อมกับออกกำลังกาย**: การ์ดล่างสุดของหน้าโภชนาการเทียบพลังงานที่กินกับที่เผาผลาญวันนี้ (7 kcal/นาที เท่ากับหน้าออกกำลังกาย), ดึงเวลาออกกำลังกายของวันนี้จากตารางเวลา และเช็คว่ามีมื้อก่อน/หลังออกกำลังกายครบหรือยัง
- แก้ไข/ลบมื้ออาหารได้ด้วยแพตเทิร์น `footerBuilder` เดียวกับหน้าตารางเวลา (ถามยืนยันก่อนลบ)
- `flutter analyze` ไม่มีปัญหา, `flutter test` ผ่าน **37 tests** (เพิ่ม 4 unit test + `test/nutrition_screen_test.dart` 3 เคส + `test/dashboard_screen_test.dart` 1 เคส)
- ยังไม่ได้ทดสอบบน emulator/มือถือจริง และยังไม่มีไฟล์ดีไซน์ `.dc.html` ของหน้านี้

### รอบ 2026-09-15 ค่ำ (เครื่อง `D:\WORK\PROGRAMPLANNER`)

| commit | งาน |
|---|---|
| `7fb005f` | **หน้าตารางเวลาแก้ไขและลบกิจกรรมได้** — แตะกิจกรรม (ทั้งมุมมองรายวันและรายสัปดาห์) เปิดฟอร์มเดิมที่กรอกค่าไว้แล้ว, ปุ่ม "ลบกิจกรรมนี้" ในฟอร์ม, ถามยืนยันก่อนลบทุกครั้ง (รวมตอนปัดซ้าย), ลบแล้วขึ้น SnackBar, ตั้งการแจ้งเตือนใหม่อัตโนมัติ |
| `b1185e6` | `android/gradle.properties`: `kotlin.incremental=false` — แก้ build APK ล้ม (ดูข้อ 4.15) |
| `29cf8f6` | บันทึก `14092026.txt` |

- `showAppFormSheet` (`lib/widgets/form_sheet.dart`) มีพารามิเตอร์ใหม่ `footerBuilder` สำหรับปุ่มรองใต้ปุ่มบันทึก — หน้าอื่นที่อยากทำ "แก้ไข/ลบ" ใช้แพตเทิร์นเดียวกับ `_openEventForm` ใน `schedule_screen.dart` ได้เลย
- `flutter analyze` ไม่มีปัญหา, `flutter test` ผ่าน **29 tests**
- APK ล่าสุด (มีฟีเจอร์แก้ไข/ลบ) อยู่ที่ `lifeplan_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` — **เซ็นด้วย debug key** เพราะเครื่องนี้ไม่มี `lifeplan-release.jks` / `key.properties` (อยู่บนเครื่องเดิม `D:\PROGRAMPLANNER`) ใช้ทดสอบได้ แต่ห้ามแจกจ่าย และติดตั้งทับแอปที่เซ็นด้วย release key ไม่ได้
- ยังไม่ได้ทดสอบฟีเจอร์แก้ไข/ลบบนมือถือ/emulator จริง (มีแค่ widget test)

**ความต่างของเครื่องนี้กับเครื่องเดิม:** โปรเจกต์อยู่ที่ `D:\WORK\PROGRAMPLANNER` (ไม่ใช่ `D:\PROGRAMPLANNER`), ไม่ได้ตั้ง `PUB_CACHE`/`GRADLE_USER_HOME` → pub cache อยู่ที่ `C:\Users\naris\AppData\Local\Pub\Cache`, เปิด Windows Developer Mode แล้ว

---

## 1. คำสั่งเริ่มงานต่อ (copy-paste ได้เลย)

```bash
cd D:/PROGRAMPLANNER/lifeplan_app

# ตั้ง environment (ถ้าเปิด terminal ใหม่ที่ยังไม่มี persistent PATH)
export JAVA_HOME="C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot"
export ANDROID_HOME="D:\android-sdk"
export ANDROID_SDK_ROOT="D:\android-sdk"
export ANDROID_AVD_HOME="D:\android-avd"
export GRADLE_USER_HOME="D:\gradle-home"
export PUB_CACHE="D:\pub-cache"
export PATH="/d/flutter/bin:/c/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot/bin:/d/android-sdk/cmdline-tools/latest/bin:/d/android-sdk/platform-tools:/d/android-sdk/emulator:$PATH"

flutter pub get
flutter analyze                 # ต้องขึ้น "No issues found!"
flutter test                    # ต้องผ่านทั้ง 29 tests

# รันบนเว็บ (เร็วสุดสำหรับเช็ค UI)
flutter build web --release
cd build/web && python -m http.server 8080   # แล้วเปิด http://localhost:8080

# รันบน Android emulator
flutter emulators --launch lifeplan_avd      # บูตครั้งแรกช้า ~1-2 นาที
flutter run -d emulator-5554
```

หมายเหตุ: `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME` และการเพิ่ม PATH ถูกตั้งเป็น **persistent user environment variable** ไว้แล้ว (`[Environment]::SetEnvironmentVariable(..., 'User')`) — เทอร์มินัล **ใหม่** (โดยเฉพาะ PowerShell ที่เปิดใหม่) ควรเห็นค่าพวกนี้อัตโนมัติโดยไม่ต้อง export เอง แต่ Git Bash session เดิมที่เปิดค้างจะไม่เห็นจนกว่าจะเปิดใหม่

---

## 2. Environment ที่ติดตั้งไว้บนเครื่องนี้

| อย่าง | ที่อยู่ / เวอร์ชัน |
|---|---|
| Flutter SDK | `D:\flutter` (stable, 3.47.4) — ติดตั้งด้วย `git clone -b stable --depth 1` |
| JDK | `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot` (Temurin 17, ผ่าน winget) |
| Android SDK | `D:\android-sdk` (command-line tools เท่านั้น ไม่ใช่ Android Studio เต็ม) |
| Android SDK packages | platform-tools, emulator, platforms android-34/36, build-tools 34.0.0/28.0.3, NDK 28.2.13676358 (Gradle โหลดเอง) |
| AVD | `lifeplan_avd` — Android 14 (API 34), Pixel 6, google_apis x86_64 — เก็บที่ `D:\android-avd` |
| Cache (ย้ายมา D: เพราะ C: พื้นที่เหลือน้อย) | `GRADLE_USER_HOME=D:\gradle-home`, `PUB_CACHE=D:\pub-cache`, `ANDROID_AVD_HOME=D:\android-avd` |
| Playwright (สำหรับแคปภาพ/ทดสอบ) | ติดตั้งไว้ที่ scratchpad ของ session เดิม ถ้าต้องใช้ใหม่ให้ `npm install playwright` ใน scratchpad แล้ว `npx playwright install chromium` |

ยังไม่ได้ติดตั้ง: Xcode (ต้องใช้ Mac สำหรับ iOS), Visual Studio C++ workload (ต้องใช้ถ้าจะ build Windows desktop .exe — ไม่จำเป็นสำหรับ Android/iOS/Web)

---

## 3. โครงสร้างโปรเจกต์ (`lifeplan_app/lib/`)

```
lib/
  main.dart                     ← entry point, เช็ค session แล้วเข้า Login หรือ RootShell
  theme/                        ← สี, ฟอนต์ (Plus Jakarta Sans)
  models/                       ← data class ของแต่ละ entity (มี toMap/fromMap)
  data/
    hive_boxes.dart             ← ชื่อ Hive box ทั้งหมด + init()
    hive_repository.dart        ← generic CRUD wrapper
    repositories/                ← repository เฉพาะแต่ละโมดูล (ต่อยอด/เพิ่ม field ที่นี่)
    seed_data.dart               ← ข้อมูลตัวอย่างตอนติดตั้งครั้งแรก
    insights.dart                ← คำนวณ % ความคืบหน้าแต่ละด้านจากข้อมูลจริง
    repositories/goal_settings_repository.dart ← เป้าหมาย (ออม/ยอดขาย/ครั้งออกกำลังกาย) ที่ผู้ใช้แก้ได้ในหน้า GoalSettingsScreen
  screens/                      ← 1 ไฟล์ต่อ 1 หน้าจอ, ชื่อไฟล์ตรงกับหน้าจอ
    nutrition_screen.dart       ← ทานอาหาร & โภชนาการ (มื้ออาหาร, สารอาหาร, วิตามิน, น้ำดื่ม, มื้อรอบออกกำลังกาย)
    crm_screen.dart             ← ลูกค้า & ขายประกัน (รายชื่อลูกค้า + รายงานผลงานประจำสัปดาห์ P-A-S-R-F-N-T)
  widgets/                      ← component ใช้ร่วม (การ์ด, ปุ่ม, ฟอร์ม, progress bar)

test/
  repository_test.dart          ← unit test ของ Hive persistence (เชื่อถือได้, เร็ว)
  widget_test.dart              ← smoke test หน้า Login เท่านั้น (ดูข้อ 5 ว่าทำไมไม่มี test แบบ tap-through)
  nutrition_screen_test.dart    ← test หน้าโภชนาการ (box in-memory แบบเดียวกับ schedule_screen_test)
  dashboard_screen_test.dart    ← test การ์ดโภชนาการบนหน้าหลัก
  crm_screen_test.dart          ← test รายงานสัปดาห์ P-A-S-R-F-N-T (แสดงผล, เลื่อนสัปดาห์, คัดลอกส่งหัวหน้า)
```

**เพิ่มโมดูลใหม่**: เพิ่ม model → เพิ่ม box name ใน `hive_boxes.dart` → สร้าง repository ต่อยอดจาก `HiveRepository<T>` → ใช้ `ValueListenableBuilder`/`AnimatedBuilder(animation: Listenable.merge([...repo.listenable()]))` ในหน้าจอเพื่อ auto-rebuild เมื่อข้อมูลเปลี่ยน

---

## 4. ปัญหาที่เจอแล้วและวิธีแก้ (กันเสียเวลาแก้ซ้ำ)

1. **Android cmdline-tools URL ผิด** — `edgedl.me.gvt1.com` ที่ได้จาก WebFetch คืนค่า 404 ให้ใช้ `https://dl.google.com/android/repository/commandlinetools-win-<build>_latest.zip` แทน (เช็คด้วย `Invoke-WebRequest -UseBasicParsing` ก่อนเสมอ — ไม่มี `-UseBasicParsing` จะ error "NonInteractive mode" ทั้งที่ไม่เกี่ยวกับ network)

2. **sdkmanager --licenses ไม่ยอมรับครบ** — เพราะ pipe แบบ PowerShell native (`"y"*20 | & sdkmanager`) ไม่เสถียรกับโปรแกรมที่ wrap เป็น .bat ให้เขียน "y" หลายบรรทัดลงไฟล์แล้ว redirect ผ่าน `cmd /c "sdkmanager --licenses < yesfile.txt"` แทน (เชื่อถือได้กว่ามาก)

3. **avdmanager ไม่รับ `--sdk_root`** — flag นี้ใช้กับ sdkmanager เท่านั้น avdmanager ใช้ `ANDROID_SDK_ROOT`/`ANDROID_HOME` จาก environment แทน

4. **`flutter test` ค้าง ~90 วินาทีแล้ว fail แบบเงียบ** — สาเหตุจริง: `testWidgets` รันใน FakeAsync zone ซึ่ง**ไม่รอ real file I/O ของ Hive** (`box.put()` เป็น I/O จริงผ่าน dart:io) ทำให้ `pumpAndSettle()` คืนค่าทั้งที่ข้อมูลยังไม่บันทึกเสร็จ
   - วิธีแก้ที่ใช้จริง: แยก unit test ของ repository ไปใช้ `test()` ธรรมดา (ไม่ใช่ `testWidgets`) ซึ่งไม่มี FakeAsync — เชื่อถือได้และเร็วกว่ามาก (`test/repository_test.dart`)
   - เก็บ `testWidgets` ไว้แค่ smoke test ที่ไม่ต้องรอ async I/O จริง

5. **`GoogleFonts.config.allowRuntimeFetching = false` ทำให้ throw ใน test** — เพราะไม่ได้ bundle ไฟล์ฟอนต์ไว้ใน assets วิธีแก้: เพิ่ม `ThemeData? theme` parameter ให้ `LifePlanApp` แล้วส่ง `ThemeData(useMaterial3: true)` ธรรมดาตอนเทสต์แทน ไม่ต้องยุ่งกับ GoogleFonts เลย

6. **Gradle ดาวน์โหลดพัง (`504` จาก GitHub)** — `services.gradle.org` redirect ไปที่ `github.com/gradle/gradle-distributions/releases/...` ซึ่งบางครั้ง edge node ที่ใกล้ (สังเกตว่าเป็น region `southeastasia`) เกิด 504 ชั่วคราว **ลองใหม่อีกครั้งมักจะผ่าน** (เจอเองก็หายเองภายใน 1-2 นาที) ถ้ายังไม่หายให้ลอง curl เช็คตรง ๆ ก่อนเสียเวลา debug ฝั่ง Flutter

7. **flutter doctor บอกว่าต้องการ Android SDK 36 + build-tools 28.0.3** — นอกจาก platform-tools/platform-34/build-tools-34 แล้ว ต้องติดตั้ง `platforms;android-36` และ `build-tools;28.0.3` เพิ่มด้วย (Flutter เช็คทั้งสองช่วงเวอร์ชัน)

8. **`sdkmanager` กลายเป็น wrapper ของ Android CLI ตัวใหม่** (cmdline-tools 23.0 ขึ้นไป) — ชื่อแพ็กเกจแบบเดิม `platforms;android-34` จะขึ้น `Package platforms not found` เพราะถูกแยกที่ `;` ให้ใช้ `android.exe` ตรง ๆ และใช้ `/` แทน `;`:
   ```bash
   D:/android-sdk/cmdline-tools/latest/bin/android.exe --sdk='D:\android-sdk' sdk install platforms/android-34 build-tools/34.0.0 system-images/android-34/google_apis/x86_64
   D:/android-sdk/cmdline-tools/latest/bin/android.exe --sdk='D:\android-sdk' sdk list --all   # ดูชื่อแพ็กเกจ
   ```
   ไม่ต้องสั่ง `--licenses` แล้ว (ขึ้น warning ว่าไม่จำเป็น) ส่วน `avdmanager.bat create avd -k "system-images;android-34;google_apis;x86_64"` ยังใช้ชื่อแบบเดิมได้

9. **`flutter build apk` ครั้งแรก fail: `sdkmanager.bat finished with non-zero exit value -1073740791 (NTSTATUS 0xC0000409)`** — Gradle พยายามโหลด NDK (`flutter.ndkVersion` = 28.2.13676358) ผ่าน `sdkmanager.bat` ตัวใหม่แล้ว crash **สั่ง build ซ้ำอีกครั้งจะผ่าน** เพราะรอบถัดไป Gradle ใช้ตัวโหลดภายในของตัวเองติดตั้ง NDK ได้ (หรือติดตั้งล่วงหน้าด้วย `android.exe sdk install ndk/28.2.13676358`)

10. **"Building with plugins requires symlink support. Please enable Developer Mode"** — `flutter test` ผ่านได้โดยไม่ต้องเปิด แต่ `flutter build apk` จะหยุดทันที (โปรเจกต์มี plugin เช่น file_picker, flutter_local_notifications) ต้องเปิด Windows Developer Mode ก่อน: `start ms-settings:developers` แล้วเปิดสวิตช์ หรือสั่งผ่าน registry (ต้องกด UAC):
    ```powershell
    Start-Process reg.exe -ArgumentList 'add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v AllowDevelopmentWithoutDevLicense /d 1' -Verb RunAs -Wait
    ```
    ตรวจว่าเปิดจริงด้วย `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense` (ต้องได้ `0x1`) — การเปิดหน้า Settings อย่างเดียวไม่ได้แปลว่าเปิดสวิตช์แล้ว

11. **Gradle แก้ชื่อ `repo.maven.apache.org` ไม่ได้ → build ล้มตอนโหลด dependency ใหม่** — อาการ: `Could not resolve org.jetbrains.kotlinx:kotlinx-coroutines-android` / "Got socket exception during request. It might be caused by SSL misconfiguration" สาเหตุจริงคือ **DNS ของเครือข่ายนี้แก้ชื่อ repo.maven.apache.org ไม่ได้** (`nslookup` ผ่าน 8.8.8.8 ได้ปกติ แต่ resolver ของเครื่องไม่ได้) วิธีแก้ที่ใช้: เพิ่ม mirror ของ Maven Central ที่ Google โฮสต์ (`https://maven-central.storage-download.googleapis.com/maven2/`) เป็น repository ตัวแรกใน `android/build.gradle.kts` และ `android/settings.gradle.kts` — ถ้าเจออาการนี้อีกให้เช็ค DNS ก่อน อย่าเพิ่งโทษ Gradle/SSL

12. **แจ้งเตือนไม่ขึ้น/ไม่มีเสียงเฉพาะบน release build (debug ปกติ)** — สาเหตุ: `isShrinkResources = true` ลบ `drawable/ic_notification` ทิ้ง เพราะไอคอนถูกอ้างชื่อจากฝั่ง Dart เท่านั้น Gradle จึงมองไม่เห็นการใช้งาน วิธีแก้: `android/app/src/main/res/raw/keep.xml` ที่ระบุ `tools:keep="@drawable/ic_notification,@raw/alarm_chime"` (เสียงเตือนโดนลบด้วยเหตุผลเดียวกัน) ตรวจว่าไอคอนรอดด้วย `aapt2 dump resources <apk> | grep ic_notification`

13. **`adb install -r` ขึ้น INSTALL_FAILED_VERSION_DOWNGRADE** — APK จาก `--split-per-abi` มี versionCode บวก 1000×ABI (x86_64 = 4001) ส่วน APK รวมเป็น 1 การสลับไปมาระหว่างสองแบบต้อง `adb uninstall` ก่อน

14. **`JAVA_HOME` ชนกับโปรเจกต์อื่น** — เครื่องนี้เดิมตั้ง `JAVA_HOME` เป็น GraalVM JDK 21 (`D:\POS\API\...`) ตอนนี้ user-level ถูกเปลี่ยนเป็น Temurin 17 แล้ว ถ้างานอื่นต้องใช้ JDK 21 ให้ export เฉพาะ session นั้น

15. **`flutter build apk` ล้มที่ `:android_file_picker:compileReleaseKotlin` — "Could not close incremental caches"** (stack trace มี `FilesKt.toRelativeString` / `RelocatableFileToPathConverter`) — สาเหตุ: Kotlin incremental compiler แปลง path เป็น relative ไม่ได้เมื่อซอร์สของ plugin (pub cache บน **C:**) กับโฟลเดอร์ build (**D:**) อยู่คนละไดรฟ์ `flutter clean` แล้ว build ใหม่ก็ยังล้มเหมือนเดิม วิธีแก้ที่ใช้: `kotlin.incremental=false` ใน `android/gradle.properties` (commit แล้ว) — build ผ่านใน ~2–4.5 นาที อีกทางคือตั้ง `PUB_CACHE` ให้อยู่ไดรฟ์เดียวกับโปรเจกต์

16. **widget test ที่กดบันทึก/ลบผ่านหน้าจอค้างไม่จบ** (ต่อจากข้อ 4) — `box.put()` บน Hive ที่เป็นไฟล์จริงไม่จบใน FakeAsync ของ `testWidgets` ฟอร์มจึงไม่ปิด และ `pumpAndSettle()` วนไม่จบ ส่วน `--timeout` ของ `flutter test` ก็ไม่ช่วยตัดให้ วิธีแก้ใน `test/schedule_screen_test.dart`: เปิด box แบบ in-memory `Hive.openBox<Map>(name, bytes: Uint8List(0))` แล้วใน `tearDown` ต้อง `await Hive.close()` ก่อน `tearDownTestHive()` (ไม่งั้นขึ้น "unsupported for memory boxes") ปุ่มที่อยู่ล่าง bottom sheet ต้อง `ensureVisible` ก่อน `tap` เพราะจอเทสต์สูงแค่ 600px — รันเทสต์ครอบด้วย `timeout 280 flutter test ...` กันค้าง

---

## 5. สิ่งที่ยังไม่ได้ทำ (เรียงตามลำดับที่ควรทำ)

- [ ] **Auth จริง** — ตอนนี้ Login/Register แค่สร้าง/บันทึก `UserProfile` ในเครื่อง ไม่มีการยืนยันตัวตนจริงกับ Google/Apple/อีเมลจริง ๆ ต้องเชื่อม Firebase Auth (หรือบริการอื่น) + ปุ่ม Google/Apple ของจริงต้องใช้ `google_sign_in` / `sign_in_with_apple` package และตั้งค่า OAuth credentials
- [x] **สำรอง/กู้คืนข้อมูลเป็นไฟล์ JSON** — ทำแล้ว (2026-09-15): `lib/data/backup.dart` + หน้า `BackupScreen` (โปรไฟล์ → สำรอง & กู้คืนข้อมูล)
  - ส่งออก: รวมทุก box เป็น JSON แล้วส่งผ่านแผงแชร์ของระบบ (share_plus) เลือกเก็บที่ไดรฟ์/แชทได้
  - กู้คืน: เลือกไฟล์ด้วย file_picker → ยืนยัน (โชว์จำนวนรายการในไฟล์) → เขียนทับทั้งหมด
  - ตรวจไฟล์ให้ครบก่อนเขียนจริง ไฟล์เสียจะไม่ทำให้ข้อมูลเดิมหายครึ่ง ๆ กลาง ๆ (มี test คุมที่ `test/backup_test.dart`)
  - ทดสอบจริงบน emulator แล้วทั้งส่งออกและกู้คืน
- [x] **ตั้งชื่อ/ไอคอน + keystore จริง + split APK** — ทำแล้ว (2026-09-15)
  - ชื่อแอปบนเครื่อง = "LifePlan", ไอคอนใหม่ (ดู `assets/icon/`, สร้างใหม่ด้วย `dart run flutter_launcher_icons`)
  - keystore จริงที่ `android/lifeplan-release.jks` + `android/key.properties` (**ไม่อยู่ใน git** — อ่าน `android/README-signing.md` ก่อน ห้ามทำหาย)
  - `--split-per-abi` ลดขนาดจาก 50.6MB เหลือ arm64 17.9MB
  - เปิด minify + shrinkResources ใน release build

- [x] **แจ้งเตือนตามตารางเวลา** — ทำแล้ว (2026-09-15): `lib/data/notifications.dart` + หน้า `NotificationSettingsScreen` (โปรไฟล์ → การแจ้งเตือน)
  - เตือนซ้ำทุกสัปดาห์ตาม weekday+เวลาของกิจกรรม, เลือกเตือนล่วงหน้าได้ (ตรงเวลา/5/10/15/30/60 นาที)
  - ตั้งใหม่ทั้งชุดทุกครั้งที่ตาราง/การตั้งค่าเปลี่ยน และตอนเปิดแอป (`main.dart`) — ไม่มีการเตือนค้างของกิจกรรมที่ลบแล้ว
  - ใช้ตารางแบบ inexact จึงไม่ต้องขอสิทธิ์ SCHEDULE_EXACT_ALARM (ไม่เด้งผู้ใช้ออกไปหน้าตั้งค่าระบบ)
  - `test/notification_schedule_test.dart` คุมการคำนวณเวลาเตือน (รวมเคสเตือนล่วงหน้าข้ามเที่ยงคืน)
  - เพิ่มเก็บค่าใน box `app_settings` (อยู่ในไฟล์สำรองด้วยแล้ว)

- [x] **ป๊อปอัป + เสียงแจ้งเตือนเมื่อถึงเวลา** — ทำแล้ว (2026-09-16)
  - **เสียง**: `android/app/src/main/res/raw/alarm_chime.wav` (ระฆัง 3 โน้ต A–C#–E สร้างด้วยสคริปต์ ไม่ได้ดึงจากที่อื่น) ตั้งเป็นเสียงของช่องแจ้งเตือน
  - เสียง/สั่นบน Android ผูกกับ *channel* และแก้ไม่ได้หลังสร้างช่องแล้ว — `NotificationService` จึงใช้ id ช่องต่างกันตามรูปแบบ (`schedule_reminders_s{0,1}_v{0,1}`) แล้วลบช่องที่ไม่ได้ใช้ทิ้งทุกครั้งที่ sync (รวมช่องเก่า `schedule_reminders`) ไม่งั้นปิดเสียงแล้วจะไม่มีผลจนกว่าจะถอนแอป
  - ต้องเพิ่ม `@raw/alarm_chime` ใน `res/raw/keep.xml` ด้วย ไม่งั้น `shrinkResources` ลบทิ้งแล้ว release build จะเงียบ (ปัญหาเดียวกับ `ic_notification` ข้อ 12) — ตรวจแล้วว่ารอด: `unzip -l app-release.apk | grep .wav`
  - **ป๊อปอัปกลางจอ**: `lib/widgets/reminder_popup.dart` — `ReminderHost` ครอบทั้งแอปผ่าน `MaterialApp.builder` + `navigatorKey` (ใช้ context ของตัวเองไม่ได้ เพราะ builder อยู่เหนือ Navigator)
  - `lib/data/reminder_watcher.dart` เป็นตัวจับเวลาฝั่งแอป (ตรวจทุก 20 วินาที) ให้ป๊อปอัปเด้ง *ตรงเวลา* ไม่ต้องรอ Android ปลุกแบบ inexact; หยุดทำงานเมื่อแอปอยู่เบื้องหลังหรือผู้ใช้ปิดการเตือน (จึงไม่มี Timer ค้างตอนรัน `flutter test`)
  - กันเด้งซ้ำด้วย `occurrenceKey` = `eventId@remindAt` — รอบสัปดาห์หน้าได้คีย์ใหม่จึงยังเด้งได้ปกติ
  - กดการแจ้งเตือนจากแถบสถานะ → เปิดป๊อปอัปของกิจกรรมนั้น (payload = `event.id`, รองรับทั้งตอนแอปเปิดค้างและตอนแอปถูกปลุกขึ้นมาใหม่)
  - ปุ่ม "เตือนอีกใน 5 นาที" ตั้งทั้ง Timer ในแอปและการแจ้งเตือนของระบบ (id 5000+) เผื่อผู้ใช้ปิดแอปไปก่อน
  - **เจตนา**: เสียงมาจากการแจ้งเตือนของระบบทางเดียว ป๊อปอัปสั่นอย่างเดียวไม่เล่นเสียงเอง — ไม่งั้นจะดังซ้อนกันสองที
  - test ใหม่: `test/reminder_watcher_test.dart`, `test/reminder_popup_test.dart` (รวมชุดทดสอบเป็น 60 tests)

- [ ] **Sync ข้ามอุปกรณ์** — Hive เก็บในเครื่องเท่านั้น ถ้าต้องการ sync ต้องมี backend (Firestore เข้ากับโครงสร้างที่ออกแบบไว้ใน `DATA_MODEL.md` ได้ทันที เพราะแต่ละ entity มี `userId` เป็น partition key อยู่แล้ว)
- [ ] **iOS build** — โค้ด Dart เดียวกันนี้พร้อมสำหรับ iOS แต่ต้องมี Mac + Xcode มา build/test จริง
- [x] **มุมมองตารางเวลารายสัปดาห์** — ทำแล้ว (2026-09-15): `ScheduleEvent` มีฟิลด์ `weekday` (1–7), `ScheduleRepository.getByWeekday()/getWeek()`, `ScheduleScreen` เป็น StatefulWidget สลับ "วัน / สัปดาห์" ได้ — มุมมองสัปดาห์เป็นตาราง 7 คอลัมน์เลื่อนแนวนอน, แถบ 7 วันกดเลือกวันได้และมีจุดบอกว่าวันไหนมีกิจกรรม, ฟอร์มเพิ่มกิจกรรมเลือกวันได้
  - เรคคอร์ดเก่าที่บันทึกก่อนหน้านี้ (ไม่มี `weekday`) จะถูกอ่านเป็นวันจันทร์ — มี test คุมไว้ที่ `repository_test.dart`
  - Dashboard "ตารางวันนี้" กรองเฉพาะ weekday ของวันนี้แล้ว (เดิมโชว์รวมทุกวัน)
  - test หน้าจอ: `test/schedule_screen_test.dart` (ใช้ Hive box แบบ in-memory เพื่อเลี่ยงปัญหา FakeAsync ข้อ 4/16)
- [x] **แก้ไข/ลบกิจกรรมในตารางเวลา** — ทำแล้ว (2026-09-15 ค่ำ) ดูข้อ 0
- [x] **โมดูลคุณภาพการนอน** — ทำแล้ว (2026-09-16) ดูข้อ 0
  - บันทึก/แก้ไข/ลบการนอนรายคืน, กราฟ 7 คืน, ค่าเฉลี่ย + ความสม่ำเสมอของเวลาเข้านอน, คำแนะนำจากข้อมูลจริง, เป้าเวลานอนตั้งเองได้
  - ต่อยอดได้: เตือน "ถึงเวลาเข้านอน" อัตโนมัติจาก `sleepTargetMinutes` + เวลาตื่นที่ตั้งไว้ (ตอนนี้ต้องสร้างกิจกรรมในตารางเวลาเอง), จับคู่คุณภาพการนอนกับคาเฟอีน/มื้อดึกที่บันทึกในโมดูลโภชนาการโดยอัตโนมัติ, กราฟย้อนหลังเป็นเดือน
- [x] **โมดูลทานอาหาร & โภชนาการ** — ทำแล้ว (2026-09-16) ดูข้อ 0
  - บันทึก/แก้ไข/ลบมื้ออาหารพร้อมสารอาหารและวิตามิน, กดเพิ่ม-ลดน้ำดื่มทีละแก้ว, เป้าหมายโภชนาการตั้งเองได้
  - ต่อยอดได้: กราฟย้อนหลังหลายวัน (ตอนนี้หน้าจอโฟกัสเฉพาะ "วันนี้" แม้ข้อมูลจะเก็บแยกตามวันอยู่แล้ว), ฐานข้อมูลเมนูอาหารไทยสำเร็จรูปเพื่อไม่ต้องกรอกกรัมเอง, แจ้งเตือนมื้ออาหาร/ดื่มน้ำแยกจากตารางเวลา
- [ ] **แก้ไขรายการในหน้าอื่น** — งานประจำ/ออกกำลังกาย/ลูกค้า/การเงิน/เรียนรู้ ยังเพิ่มได้อย่างเดียว (บางหน้าปัดลบได้) ใช้แพตเทิร์น `footerBuilder` + `_openEventForm(existing:)` จากหน้าตารางเวลา หรือ `_openMealForm(existing:)` จากหน้าโภชนาการได้
- [ ] **ทดสอบแก้ไข/ลบตารางเวลาบนเครื่องจริง** และ build APK ด้วย release key บนเครื่องที่มี keystore
- [x] **เป้าหมายที่ตั้งค่าได้เอง** — ทำแล้ว (2026-09-15): `GoalSettings` model + box `goal_settings` + หน้า `GoalSettingsScreen` (เข้าจาก โปรไฟล์ → ตั้งค่าเป้าหมาย) ทุกหน้าที่ใช้เป้าหมาย rebuild อัตโนมัติเมื่อบันทึก
  - การ์ดออกกำลังกายบน Dashboard ใช้ "เสร็จ / เป้าต่อสัปดาห์" ตรงกับ % แล้ว (2026-09-15)
- [ ] **Windows desktop build** — ต้องติดตั้ง Visual Studio "Desktop development with C++" workload ก่อน ถ้าต้องการ .exe (ไม่จำเป็นสำหรับเป้าหมายหลักคือ Android/iOS)

---

## 6. ลิงก์ / ไฟล์อ้างอิง

- ดีไซน์ (Claude Design canvas, แก้ไขได้): https://claude.ai/code/artifact/c58583c1-3ff8-4b8f-8907-45dc918aa714
- ภาพหน้าจอดีไซน์ + ภาพแอปที่รันจริง: `screenshots/` (ไฟล์ `flutter_*` = build web, `live_*` = คลิกทดสอบผ่าน Playwright, `emulator_*` = รันจริงบน Android emulator)
- โครงสร้างข้อมูล: `DATA_MODEL.md`
- ภาพรวมฟีเจอร์/โมดูล: `README.md`
- บันทึกรอบโมดูลโภชนาการ (16 ก.ย. 2026): `16092026 โภชนาการ.md`
