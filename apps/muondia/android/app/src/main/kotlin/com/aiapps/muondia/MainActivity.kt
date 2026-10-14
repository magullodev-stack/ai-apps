package com.aiapps.muondia

import android.content.Intent
import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return
        val method: String
        val args: Any?
        when (intent.action) {
            "com.aiapps.muondia.DEV_SHOW_AUTH" -> {
                method = "showAuth"
                args = null
            }
            "com.aiapps.muondia.DEV_OPEN_EXPERIENCE" -> {
                method = "openExperience"
                args = mapOf(
                    "experience" to intent.getStringExtra("experience"),
                    "state" to intent.getStringExtra("state")
                )
            }
            else -> return
        }
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, "muondia/development")
                .invokeMethod(method, args)
        }
    }
}
