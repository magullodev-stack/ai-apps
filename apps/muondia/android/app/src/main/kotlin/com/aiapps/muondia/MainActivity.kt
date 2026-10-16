package com.aiapps.muondia

import android.content.Intent
import android.content.pm.ApplicationInfo
import io.flutter.embedding.engine.FlutterEngine
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return

        val locationFile = File(filesDir, "ai_apps_active_experience.txt")
        // Un arranque de proceso no debe reutilizar el estado anterior.
        locationFile.delete()
        val safeId = Regex("^[a-z][a-z0-9_-]{0,63}$")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "muondia/development_location").setMethodCallHandler { call, result ->
            if (call.method != "setActiveLocation") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val args = call.arguments as? Map<*, *>
            val mode = args?.get("mode") as? String
            val experience = args?.get("experience") as? String ?: ""
            val state = args?.get("state") as? String ?: ""
            if ((mode != "preview" && mode != "real") ||
                (experience.isNotEmpty() && !safeId.matches(experience)) ||
                (state.isNotEmpty() && !safeId.matches(state)) ||
                (mode == "preview" && (experience.isEmpty() || state.isEmpty())) ||
                (mode == "real" && (experience.isNotEmpty() || state.isNotEmpty()))) {
                result.error("invalid_location", "Ubicación de depuración inválida", null)
                return@setMethodCallHandler
            }
            // Archivo privado de la APK depurable, legible mediante adb run-as.
            // No contiene datos personales y nunca se expone en release.
            try {
                locationFile.writeText("$mode:$experience:$state")
                result.success(null)
            } catch (_: Exception) {
                result.error("location_unavailable", "No se pudo registrar la vista", null)
            }
        }
    }

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
            "com.aiapps.muondia.DEV_OPEN_REAL_FLOW" -> {
                method = "openRealFlow"
                args = null
            }
            "com.aiapps.muondia.DEV_OPEN_EXPERIENCE" -> {
                method = "openExperience"
                args = mapOf(
                    "experience" to intent.getStringExtra("experience"),
                    "state" to intent.getStringExtra("state")
                )
            }
            "com.aiapps.muondia.DEV_ASSET_VISIBILITY" -> {
                val asset = intent.getStringExtra("asset") ?: return
                // El host Android no permite rutas fuera del bundle.
                if (!asset.startsWith("assets/") || asset.contains("..")) return
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, "ai_apps/visual_inspector").invokeMethod(
                        "setAssetVisibility",
                        mapOf("asset" to asset,
                              "visible" to intent.getBooleanExtra("visible", true))
                    )
                }
                return
            }
            else -> return
        }
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, "muondia/development")
                .invokeMethod(method, args)
        }
    }
}
