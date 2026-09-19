package com.gpsapp.gps_app

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(RingerModeWatcher())
        flutterEngine.plugins.add(NativeBridgePlugin())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = getSharedPreferences(MosqueForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean(MosqueForegroundService.KEY_MONITORING_ENABLED, true)
        if (enabled) {
            MosqueForegroundService.startService(this)
        }
    }
}
