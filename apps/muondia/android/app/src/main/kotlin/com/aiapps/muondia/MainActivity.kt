package com.aiapps.muondia

import android.content.Intent
import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        // El atajo de desarrollo se envía desde VS Code mediante un intent
        // explícito: no depende del teclado ni del visor EmbeDroid.
        if (intent.action != "com.aiapps.muondia.DEV_SHOW_AUTH" ||
            applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0
        ) {
            return
        }

        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, "muondia/development")
                .invokeMethod("showAuth", null)
        }
    }
}
