# การเซ็น release APK

## ไฟล์ที่เกี่ยวข้อง (ทั้งคู่ **ไม่อยู่ใน git** ตาม `.gitignore`)

| ไฟล์ | คืออะไร |
|---|---|
| `android/lifeplan-release.jks` | keystore (PKCS12, alias `lifeplan`, อายุใบรับรอง 10,000 วัน) |
| `android/key.properties` | รหัสผ่าน + alias ที่ Gradle อ่านตอน build |

SHA-256 fingerprint ของใบรับรองปัจจุบัน (keystore ชุดใหม่ สร้าง 2026-09-19 บนเครื่อง `D:\WORK\PROGRAMPLANNER`
หลังจากของเดิมหายไปพร้อมเครื่องเก่า — แอปที่เซ็นด้วย key เก่าจะอัปเดตทับด้วยตัวนี้ไม่ได้ ต้องถอนแล้วลงใหม่ครั้งเดียว):

```
F6:ED:6A:23:9A:5A:20:F7:73:26:5F:CB:3B:1B:01:06:9C:3A:F4:C0:4A:52:01:1D:EF:97:08:3E:19:80:0A:30
```

## ⚠️ สำคัญมาก

**สำรองทั้งสองไฟล์นี้ไว้นอกเครื่อง** (เช่นใส่ไว้ในที่เก็บรหัสผ่าน หรือไดรฟ์ส่วนตัว)
ถ้าไฟล์หายหรือลืมรหัสผ่าน จะ **อัปเดตแอปทับตัวที่ติดตั้งไปแล้วไม่ได้อีกเลย**
ผู้ใช้จะต้องถอนแอปเก่าแล้วลงใหม่ (ข้อมูลในเครื่องหายหมด) และถ้าขึ้น Play Store ไปแล้ว
จะไม่สามารถส่งเวอร์ชันใหม่ของแอปตัวเดิมได้

## build

```bash
cd lifeplan_app

# APK แยกตาม CPU (ไฟล์เล็กกว่าเดิม 3 เท่า) — เอาไว้แจกเอง/ติดตั้งตรง
flutter build apk --release --split-per-abi
# ผลลัพธ์: build/app/outputs/flutter-apk/app-<abi>-release.apk
# เครื่อง Android ทั่วไปปัจจุบันใช้ app-arm64-v8a-release.apk

# สำหรับขึ้น Play Store
flutter build appbundle --release
```

ตรวจว่าเซ็นด้วย key จริง (ไม่ใช่ debug key):

```bash
D:/android-sdk/build-tools/34.0.0/apksigner.bat verify --print-certs \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# ต้องขึ้น: Signer #1 certificate DN: CN=LifePlan, O=LifePlan, C=TH
```

ถ้าเครื่องไหนไม่มี `key.properties` (เช่นเพิ่ง clone repo) `build.gradle.kts` จะถอยไปเซ็นด้วย
debug key อัตโนมัติเพื่อให้ build ผ่าน — APK นั้นแจกจ่ายไม่ได้ ใช้ทดสอบเท่านั้น

## สร้าง keystore ใหม่ (กรณีเริ่มใหม่ทั้งหมด)

```bash
keytool -genkeypair -keystore android/lifeplan-release.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias lifeplan \
  -dname "CN=LifePlan, O=LifePlan, C=TH"
```

แล้วสร้าง `android/key.properties`:

```properties
storePassword=<รหัส>
keyPassword=<รหัส>
keyAlias=lifeplan
storeFile=lifeplan-release.jks
```
