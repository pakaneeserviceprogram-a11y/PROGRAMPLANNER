# Flutter/Dart ไม่ต้องการ rule เพิ่มเป็นพิเศษ — ไฟล์นี้ไว้ใส่ rule ของ library ที่ใช้ reflection

# ปลั๊กอิน google_mlkit_text_recognition อ้างถึงตัวอ่านภาษาจีน/ญี่ปุ่น/เกาหลี/เทวนาครี
# ซึ่งเป็น dependency แยกที่แอปนี้ไม่ได้ใส่ (สแกนนามบัตรใช้เฉพาะอักษรละติน)
# ไม่ใส่บรรทัดนี้ R8 จะล้มทั้ง build ด้วย "Missing class ...TextRecognizerOptions"
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
