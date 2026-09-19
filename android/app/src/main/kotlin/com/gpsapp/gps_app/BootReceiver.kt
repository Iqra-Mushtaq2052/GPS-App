package com.gpsapp.gps_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        val action = intent?.action
        if (action == Intent.ACTION_BOOT_COMPLETED || action == "android.intent.action.QUICKBOOT_POWERON") {
            val prefs = context.getSharedPreferences(MosqueForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
            val isEnabled = prefs.getBoolean(MosqueForegroundService.KEY_MONITORING_ENABLED, false)
            if (isEnabled) {
                MosqueForegroundService.startService(context)
            }
        }
    }
}
