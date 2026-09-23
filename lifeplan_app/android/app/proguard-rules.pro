# Flutter/Dart ไม่ต้องการ rule เพิ่มเป็นพิเศษ — ไฟล์นี้ไว้ใส่ rule ของ library ที่ใช้ reflection

# ML Kit โหลดโมดูลด้วย "ชื่อคลาส" ตอนรันจริง ถ้า R8 เปลี่ยนชื่อ/ตัดทิ้ง
# แอปจะพังเฉพาะ release build (debug ไม่ minify จึงไม่เจอ) — อาการคือสแกนนามบัตรแล้ว error
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_commons.** { *; }

# ปลั๊กอิน google_mlkit_text_recognition อ้างถึงตัวอ่านภาษาจีน/ญี่ปุ่น/เกาหลี/เทวนาครี
# ซึ่งเป็น dependency แยกที่แอปนี้ไม่ได้ใส่ (สแกนนามบัตรใช้เฉพาะอักษรละติน)
# ไม่ใส่บรรทัดนี้ R8 จะล้มทั้ง build ด้วย "Missing class ...TextRecognizerOptions"
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
