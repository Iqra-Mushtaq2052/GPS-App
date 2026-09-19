package com.gpsapp.gps_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver to revive MosqueForegroundService if app task is swiped away
 * or killed by aggressive OEM task managers (Vivo, Xiaomi, Oppo).
 */
class ServiceRestarterReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.d("MosqueService", "ServiceRestarterReceiver: Reviving MosqueForegroundService")
        val prefs = context.getSharedPreferences(MosqueForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
        val monitoringEnabled = prefs.getBoolean(MosqueForegroundService.KEY_MONITORING_ENABLED, true)

        if (monitoringEnabled) {
            val serviceIntent = Intent(context, MosqueForegroundService::class.java).apply {
                action = MosqueForegroundService.ACTION_START
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                Log.d("MosqueService", "ServiceRestarterReceiver: Successfully started MosqueForegroundService")
            } catch (e: Exception) {
                Log.e("MosqueService", "ServiceRestarterReceiver: Failed to restart service", e)
            }
        }
    }
}
