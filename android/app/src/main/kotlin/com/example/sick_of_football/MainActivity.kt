package com.example.sick_of_football

import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val screenCaptureChannel = "sick_of_football/screen_capture"
    private var screenCaptureProtected = false

    private fun updateScreenCaptureProtection() {
        if (screenCaptureProtected) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onResume() {
        super.onResume()
        updateScreenCaptureProtection()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenCaptureChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    screenCaptureProtected = true
                    updateScreenCaptureProtection()
                    result.success(null)
                }
                "disable" -> {
                    screenCaptureProtected = false
                    updateScreenCaptureProtection()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
