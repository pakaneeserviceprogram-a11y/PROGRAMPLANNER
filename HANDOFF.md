# LifePlan — Handoff / เอกสารต่องาน

อัปเดตล่าสุด: 2026-09-15 (ย้ายโปรเจกต์มาที่ `D:\PROGRAMPLANNER` + ติดตั้ง environment ใหม่) — ใช้ไฟล์นี้เพื่อกลับมาทำงานต่อได้เร็ว ไม่ต้องไล่อ่านทั้งบทสนทนาใหม่

ดูภาพรวมโปรเจกต์/ฟีเจอร์ที่ `README.md`, โครงสร้างข้อมูลที่ `DATA_MODEL.md` — ไฟล์นี้เน้นเฉพาะ "จะทำต่อยังไง"

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
flutter test                    # ต้องผ่านทั้ง 12 tests

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
  widgets/                      ← component ใช้ร่วม (การ์ด, ปุ่ม, ฟอร์ม, progress bar)

test/
  repository_test.dart          ← unit test ของ Hive persistence (เชื่อถือได้, เร็ว)
  widget_test.dart              ← smoke test หน้า Login เท่านั้น (ดูข้อ 5 ว่าทำไมไม่มี test แบบ tap-through)
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

10. **`flutter pub get` เตือนเรื่อง symlink / Developer Mode** — build Android/Web ได้โดยไม่ต้องเปิด แต่ถ้าจะ build Windows desktop ต้องเปิด Developer Mode (`start ms-settings:developers`)

11. **Gradle แก้ชื่อ `repo.maven.apache.org` ไม่ได้ → build ล้มตอนโหลด dependency ใหม่** — อาการ: `Could not resolve org.jetbrains.kotlinx:kotlinx-coroutines-android` / "Got socket exception during request. It might be caused by SSL misconfiguration" สาเหตุจริงคือ **DNS ของเครือข่ายนี้แก้ชื่อ repo.maven.apache.org ไม่ได้** (`nslookup` ผ่าน 8.8.8.8 ได้ปกติ แต่ resolver ของเครื่องไม่ได้) วิธีแก้ที่ใช้: เพิ่ม mirror ของ Maven Central ที่ Google โฮสต์ (`https://maven-central.storage-download.googleapis.com/maven2/`) เป็น repository ตัวแรกใน `android/build.gradle.kts` และ `android/settings.gradle.kts` — ถ้าเจออาการนี้อีกให้เช็ค DNS ก่อน อย่าเพิ่งโทษ Gradle/SSL

12. **`JAVA_HOME` ชนกับโปรเจกต์อื่น** — เครื่องนี้เดิมตั้ง `JAVA_HOME` เป็น GraalVM JDK 21 (`D:\POS\API\...`) ตอนนี้ user-level ถูกเปลี่ยนเป็น Temurin 17 แล้ว ถ้างานอื่นต้องใช้ JDK 21 ให้ export เฉพาะ session นั้น

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

- [ ] **Sync ข้ามอุปกรณ์** — Hive เก็บในเครื่องเท่านั้น ถ้าต้องการ sync ต้องมี backend (Firestore เข้ากับโครงสร้างที่ออกแบบไว้ใน `DATA_MODEL.md` ได้ทันที เพราะแต่ละ entity มี `userId` เป็น partition key อยู่แล้ว)
- [ ] **iOS build** — โค้ด Dart เดียวกันนี้พร้อมสำหรับ iOS แต่ต้องมี Mac + Xcode มา build/test จริง
- [x] **มุมมองตารางเวลารายสัปดาห์** — ทำแล้ว (2026-09-15): `ScheduleEvent` มีฟิลด์ `weekday` (1–7), `ScheduleRepository.getByWeekday()/getWeek()`, `ScheduleScreen` เป็น StatefulWidget สลับ "วัน / สัปดาห์" ได้ — มุมมองสัปดาห์เป็นตาราง 7 คอลัมน์เลื่อนแนวนอน, แถบ 7 วันกดเลือกวันได้และมีจุดบอกว่าวันไหนมีกิจกรรม, ฟอร์มเพิ่มกิจกรรมเลือกวันได้
  - เรคคอร์ดเก่าที่บันทึกก่อนหน้านี้ (ไม่มี `weekday`) จะถูกอ่านเป็นวันจันทร์ — มี test คุมไว้ที่ `repository_test.dart`
  - Dashboard "ตารางวันนี้" กรองเฉพาะ weekday ของวันนี้แล้ว (เดิมโชว์รวมทุกวัน)
  - test หน้าจอ: `test/schedule_screen_test.dart` (เขียน Hive ใน `setUp` ก่อน pump เพื่อเลี่ยงปัญหา FakeAsync ข้อ 4)
- [x] **เป้าหมายที่ตั้งค่าได้เอง** — ทำแล้ว (2026-09-15): `GoalSettings` model + box `goal_settings` + หน้า `GoalSettingsScreen` (เข้าจาก โปรไฟล์ → ตั้งค่าเป้าหมาย) ทุกหน้าที่ใช้เป้าหมาย rebuild อัตโนมัติเมื่อบันทึก
  - การ์ดออกกำลังกายบน Dashboard ใช้ "เสร็จ / เป้าต่อสัปดาห์" ตรงกับ % แล้ว (2026-09-15)
- [ ] **Windows desktop build** — ต้องติดตั้ง Visual Studio "Desktop development with C++" workload ก่อน ถ้าต้องการ .exe (ไม่จำเป็นสำหรับเป้าหมายหลักคือ Android/iOS)

---

## 6. ลิงก์ / ไฟล์อ้างอิง

- ดีไซน์ (Claude Design canvas, แก้ไขได้): https://claude.ai/code/artifact/c58583c1-3ff8-4b8f-8907-45dc918aa714
- ภาพหน้าจอดีไซน์ + ภาพแอปที่รันจริง: `screenshots/` (ไฟล์ `flutter_*` = build web, `live_*` = คลิกทดสอบผ่าน Playwright, `emulator_*` = รันจริงบน Android emulator)
- โครงสร้างข้อมูล: `DATA_MODEL.md`
- ภาพรวมฟีเจอร์/โมดูล: `README.md`
