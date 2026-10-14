package com.lifeplan.lifeplan_app

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (ล็อกแอปด้วยลายนิ้วมือ/PIN) ต้องใช้ FragmentActivity
class MainActivity : FlutterFragmentActivity() {

    // ซ่อนภาพหน้าจอ LifePlan ในรายการแอปที่เพิ่งใช้ (มีรายชื่อลูกค้า) แต่ยังแคปหน้าจอได้ตามปกติ
    // — ทีมต้องแคปหน้าจอ error ส่งผู้ดูแลได้ จึงไม่ตั้ง FLAG_SECURE ค้างไว้ตลอด
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }

    // Android 12 ลงไปไม่มี API ข้างบน — ตั้ง FLAG_SECURE เฉพาะตอนออกจากแอป (ระบบถ่ายภาพตอนนี้)
    // แล้วเอาออกเมื่อกลับมา
    override fun onPause() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
