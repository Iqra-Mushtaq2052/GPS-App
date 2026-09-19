package com.gpsapp.gps_app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * 100% Native Android Foreground Service for Mosque Proximity Monitoring & Auto-Vibrate.
 * Runs independently of the Flutter Engine / Dart VM.
 *
 * Rules:
 * 1. ONLY active when device Location / GPS is turned ON and monitoring is enabled.
 * 2. If GPS is turned OFF, vibration system immediately pauses and normal ringer is restored.
 * 3. Partial WakeLock keeps GPS location listening alive in background/screen-off.
 * 4. Multi-provider listening (FUSED, GPS, NETWORK) with 0m minDistance for stationary fixes.
 * 5. Instant Native Ringer Receiver (RINGER_MODE_CHANGED_ACTION) so whenever user tries to unmute
 *    inside a mosque, it INSTANTLY and REPEATEDLY re-applies Vibrate mode (as long as GPS is ON).
 * 6. 3-Second Active Watchdog Timer checking sound mode continuously.
 * 7. Median Distance Filter (5-sample sliding window).
 * 8. Hysteresis Exit Buffer (+30m past mosque radius).
 * 9. Minimum Dwell Lock (45s lock once inside).
 * 10. 4-Consecutive Confirmation Exit Filter.
 * 11. Direct AudioManager VIBRATE mode.
 */
class MosqueForegroundService : Service(), LocationListener {

    companion object {
        const val TAG = "MosqueService"
        const val CHANNEL_ID = "masjid_foreground_channel"
        const val CHANNEL_NAME = "Masjid Proximity Monitoring"
        const val NOTIFICATION_ID = 9991

        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_MOSQUES_JSON = "flutter.native_saved_mosques"
        const val KEY_MONITORING_ENABLED = "flutter.native_monitoring_enabled"
        const val KEY_PREVIOUS_RINGER_MODE = "native_previous_ringer_mode"
        const val KEY_SILENCED_BY_SERVICE = "native_silenced_by_service"

        const val ACTION_START = "com.gpsapp.gps_app.ACTION_START"
        const val ACTION_STOP = "com.gpsapp.gps_app.ACTION_STOP"
        const val ACTION_UPDATE_MOSQUES = "com.gpsapp.gps_app.ACTION_UPDATE_MOSQUES"

        // Stability & Hysteresis Constants
        const val EXIT_BUFFER_METERS = 30.0f
        const val MAX_ACCEPTABLE_ACCURACY_METERS = 40.0f
        const val REQUIRED_CONSECUTIVE_EXIT_COUNT = 4
        const val MIN_DWELL_TIME_MS = 45000L // 45 seconds lock on enter
        const val MAX_PLAUSIBLE_SPEED_MPS = 25.0f // 90 km/h

        fun startService(context: Context) {
            val intent = Intent(context, MosqueForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, MosqueForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var locationManager: LocationManager? = null
    private var audioManager: AudioManager? = null
    private var notificationManager: NotificationManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var ringerReceiver: BroadcastReceiver? = null

    private data class MosqueItem(
        val id: Int,
        val name: String,
        val lat: Double,
        val lng: Double,
        val radius: Int,
        val enabled: Boolean
    )

    private val mosques = mutableListOf<MosqueItem>()

    // State Tracking
    private var currentActiveMosque: MosqueItem? = null
    private var isCurrentlySilenced = false
    private var consecutiveOutsideReadings = 0
    private var lastEnterTimestampMs = 0L
    private var lastLocation: Location? = null

    // Distance Smoothing (Median Filter per Mosque)
    private val distanceHistory = mutableMapOf<Int, MutableList<Float>>()

    private val watchdogRunnable = object : Runnable {
        override fun run() {
            if (isGpsEnabled()) {
                reEnforceVibrateIfInside()
            }
            mainHandler.postDelayed(this, 3000L)
        }
    }

    /**
     * Checks whether location/GPS is currently turned ON by the user.
     */
    private fun isGpsEnabled(): Boolean {
        val lm = locationManager ?: return false
        return try {
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        } catch (e: Exception) {
            false
        }
    }

    private fun handleGpsDisabled() {
        Log.d(TAG, "Location/GPS was turned OFF! Pausing vibration system & restoring normal ringer")
        currentActiveMosque = null
        consecutiveOutsideReadings = 0
        restorePhone()
        updateNotification(
            title = "⚠️ Location (GPS) Band Hai",
            text = "GPS band hone par auto-vibrate system pause hai. Pehle GPS ON karein."
        )
    }

    private fun handleGpsEnabled() {
        Log.d(TAG, "Location/GPS was turned ON! Resuming vibration monitoring")
        updateNotification(
            title = "🕌 Mosque Auto-Vibrate Active",
            text = "Monitoring ${mosques.count { it.enabled }} saved mosques in background"
        )
        startLocationListening()
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate: Initializing native service")
        locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

        // Acquire partial wake lock to prevent Doze from killing background GPS
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "MosqueForegroundService::WakeLock")?.apply {
                setReferenceCounted(false)
                acquire(12 * 60 * 60 * 1000L) // 12 hours max hold
            }
            Log.d(TAG, "WakeLock acquired: ${wakeLock?.isHeld}")
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring WakeLock", e)
        }

        // Register Native Ringer & GPS Provider Change Watcher
        try {
            ringerReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    Log.d(TAG, "Broadcast received: ${intent?.action}")
                    if (intent?.action == LocationManager.PROVIDERS_CHANGED_ACTION) {
                        if (isGpsEnabled()) {
                            handleGpsEnabled()
                        } else {
                            handleGpsDisabled()
                        }
                    } else {
                        if (isGpsEnabled()) {
                            reEnforceVibrateIfInside()
                        }
                    }
                }
            }
            val filter = IntentFilter().apply {
                addAction(AudioManager.RINGER_MODE_CHANGED_ACTION)
                addAction(NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED)
                addAction("android.media.VOLUME_CHANGED_ACTION")
                addAction(LocationManager.PROVIDERS_CHANGED_ACTION)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(ringerReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(ringerReceiver, filter)
            }
            Log.d(TAG, "Registered native ringer and GPS provider receiver successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error registering ringerReceiver", e)
        }

        createNotificationChannel()
        loadMosquesFromPrefs()

        // Start 3-second active watchdog to continuously re-enforce vibrate if unmuted inside
        startWatchdogTimer()

        // Call startForeground immediately in onCreate to satisfy Android 14+ FGS requirements
        val initialTitle = if (isGpsEnabled()) "🕌 Mosque Auto-Vibrate Active" else "⚠️ Location (GPS) Band Hai"
        val initialText = if (isGpsEnabled()) {
            "Monitoring ${mosques.count { it.enabled }} saved mosques in background"
        } else {
            "GPS band hone par auto-vibrate system pause hai. Pehle GPS ON karein."
        }

        val notification = buildForegroundNotification(title = initialTitle, text = initialText)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        if (isGpsEnabled()) {
            startLocationListening()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")
        when (intent?.action) {
            ACTION_STOP -> {
                restorePhone()
                stopLocationListening()
                stopWatchdogTimer()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE_MOSQUES -> {
                loadMosquesFromPrefs()
            }
            else -> {
                loadMosquesFromPrefs()
                if (isGpsEnabled()) {
                    val notif = buildForegroundNotification(
                        title = "🕌 Mosque Auto-Vibrate Active",
                        text = "Monitoring ${mosques.count { it.enabled }} saved mosques in background"
                    )
                    notificationManager?.notify(NOTIFICATION_ID, notif)
                    startLocationListening()
                } else {
                    handleGpsDisabled()
                }
                startWatchdogTimer()
            }
        }
        return START_STICKY
    }

    private fun startWatchdogTimer() {
        mainHandler.removeCallbacks(watchdogRunnable)
        mainHandler.postDelayed(watchdogRunnable, 3000L)
    }

    private fun stopWatchdogTimer() {
        mainHandler.removeCallbacks(watchdogRunnable)
    }

    private fun reEnforceVibrateIfInside() {
        if (!isGpsEnabled()) {
            Log.d(TAG, "reEnforceVibrateIfInside: GPS is OFF, skipping")
            return
        }

        val am = audioManager ?: return
        val active = currentActiveMosque ?: return
        val currentMode = am.ringerMode

        if (currentMode != AudioManager.RINGER_MODE_VIBRATE) {
            Log.d(TAG, "User un-vibrated while inside ${active.name}! Repeatedly re-forcing VIBRATE now!")
            silencePhone(active.name)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background GPS monitoring for nearby mosques"
                setShowBadge(false)
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(title: String, text: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                this, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(title: String, text: String) {
        val notification = buildForegroundNotification(title, text)
        notificationManager?.notify(NOTIFICATION_ID, notification)
    }

    private fun loadMosquesFromPrefs() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val jsonStr = prefs.getString(KEY_MOSQUES_JSON, null)
            mosques.clear()
            distanceHistory.clear()
            if (!jsonStr.isNullOrEmpty()) {
                val array = JSONArray(jsonStr)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    mosques.add(
                        MosqueItem(
                            id = obj.optInt("id", i),
                            name = obj.optString("name", "Mosque"),
                            lat = obj.optDouble("lat", 0.0),
                            lng = obj.optDouble("lng", 0.0),
                            radius = obj.optInt("radius", 40),
                            enabled = obj.optBoolean("enabled", true)
                        )
                    )
                }
            }
            Log.d(TAG, "Loaded ${mosques.size} mosques from prefs (Enabled: ${mosques.count { it.enabled }})")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading mosques from prefs", e)
        }
    }

    private fun startLocationListening() {
        if (!isGpsEnabled()) {
            Log.d(TAG, "startLocationListening: GPS is OFF, skipping")
            return
        }

        val lm = locationManager ?: return
        Log.d(TAG, "startLocationListening: Requesting location updates")

        // 1. Immediately evaluate last known locations
        try {
            val lastGps = lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            val lastNet = lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            val best = when {
                lastGps != null && lastNet != null -> if (lastGps.time > lastNet.time) lastGps else lastNet
                lastGps != null -> lastGps
                else -> lastNet
            }
            if (best != null) {
                Log.d(TAG, "Initial check with lastKnownLocation: lat=${best.latitude}, lng=${best.longitude}")
                checkProximity(best)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException getting last known location", e)
        }

        // 2. Register multi-provider listeners with 0.0f minDistance
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    lm.requestLocationUpdates(
                        LocationManager.FUSED_PROVIDER,
                        3000L,
                        0.0f,
                        this,
                        Looper.getMainLooper()
                    )
                    Log.d(TAG, "Registered FUSED_PROVIDER location listener")
                } catch (e: Exception) {
                    Log.w(TAG, "FUSED_PROVIDER not available", e)
                }
            }

            if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                lm.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    3000L,
                    0.0f,
                    this,
                    Looper.getMainLooper()
                )
                Log.d(TAG, "Registered GPS_PROVIDER location listener")
            }

            if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                lm.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    5000L,
                    0.0f,
                    this,
                    Looper.getMainLooper()
                )
                Log.d(TAG, "Registered NETWORK_PROVIDER location listener")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException registering location listeners", e)
        }
    }

    private fun stopLocationListening() {
        Log.d(TAG, "stopLocationListening")
        locationManager?.removeUpdates(this)
    }

    override fun onLocationChanged(location: Location) {
        if (!isGpsEnabled()) {
            return
        }
        Log.d(TAG, "GPS Fix: lat=${location.latitude}, lng=${location.longitude}, acc=${location.accuracy}m, provider=${location.provider}")
        checkProximity(location)
    }

    private fun getSmoothedDistance(mosqueId: Int, rawDistance: Float): Float {
        val history = distanceHistory.getOrPut(mosqueId) { mutableListOf() }
        history.add(rawDistance)
        if (history.size > 5) {
            history.removeAt(0)
        }
        val sorted = history.sorted()
        return sorted[sorted.size / 2]
    }

    private fun checkProximity(location: Location) {
        if (!isGpsEnabled()) {
            Log.d(TAG, "checkProximity skipped: GPS is OFF")
            return
        }

        // 1. Discard inaccurate readings
        if (location.hasAccuracy() && location.accuracy > MAX_ACCEPTABLE_ACCURACY_METERS) {
            Log.d(TAG, "Discarded fix: accuracy ${location.accuracy}m > ${MAX_ACCEPTABLE_ACCURACY_METERS}m")
            return
        }

        // 2. Discard teleport speed jumps
        val prevLoc = lastLocation
        if (prevLoc != null) {
            val elapsedSec = (location.time - prevLoc.time) / 1000.0f
            if (elapsedSec > 0.5f) {
                val speed = location.distanceTo(prevLoc) / elapsedSec
                if (speed > MAX_PLAUSIBLE_SPEED_MPS) {
                    Log.d(TAG, "Discarded teleport speed jump: ${speed}m/s")
                    return
                }
            }
        }
        lastLocation = location

        val activeMosques = mosques.filter { it.enabled }
        if (activeMosques.isEmpty()) return

        var matchedInsideMosque: MosqueItem? = null

        // 3. Evaluate each active mosque with median smoothed distance
        for (mosque in activeMosques) {
            val mosqueLoc = Location("").apply {
                latitude = mosque.lat
                longitude = mosque.lng
            }
            val rawDistance = location.distanceTo(mosqueLoc)
            val smoothedDistance = getSmoothedDistance(mosque.id, rawDistance)

            // If we are currently inside THIS mosque, require moving past radius + 30m buffer
            val threshold = if (currentActiveMosque?.id == mosque.id) {
                mosque.radius.toFloat() + EXIT_BUFFER_METERS
            } else {
                mosque.radius.toFloat()
            }

            Log.d(TAG, "Mosque '${mosque.name}': raw=${rawDistance.toInt()}m, smoothed=${smoothedDistance.toInt()}m, threshold=${threshold.toInt()}m")

            if (smoothedDistance <= threshold) {
                matchedInsideMosque = mosque
                break
            }
        }

        val currentTimeMs = SystemClock.elapsedRealtime()

        if (matchedInsideMosque != null) {
            // User is confirmed INSIDE
            consecutiveOutsideReadings = 0
            val am = audioManager
            val currentMode = am?.ringerMode ?: AudioManager.RINGER_MODE_NORMAL
            Log.d(TAG, "STATUS: INSIDE '${matchedInsideMosque.name}' (currentMode=$currentMode, isCurrentlySilenced=$isCurrentlySilenced)")

            // ALWAYS enforce vibrate mode if currentMode is not vibrate
            if (currentActiveMosque?.id != matchedInsideMosque.id || !isCurrentlySilenced || currentMode != AudioManager.RINGER_MODE_VIBRATE) {
                currentActiveMosque = matchedInsideMosque
                lastEnterTimestampMs = currentTimeMs
                Log.d(TAG, "Triggering SILENCE for: ${matchedInsideMosque.name}")
                silencePhone(matchedInsideMosque.name)
            }
        } else {
            // User is outside the enter radius + exit buffer
            if (currentActiveMosque != null) {
                // Minimum Dwell Time Lock: Prevent exit for at least 45 seconds after entering
                val timeSinceEnterMs = currentTimeMs - lastEnterTimestampMs
                if (timeSinceEnterMs < MIN_DWELL_TIME_MS) {
                    Log.d(TAG, "DWELL LOCK active: ${timeSinceEnterMs / 1000}s / ${MIN_DWELL_TIME_MS / 1000}s")
                    return // In dwell lock
                }

                consecutiveOutsideReadings++
                Log.d(TAG, "STATUS: OUTSIDE confirmation $consecutiveOutsideReadings/$REQUIRED_CONSECUTIVE_EXIT_COUNT")

                // Require 4 consecutive readings consistently outside before restoring
                if (consecutiveOutsideReadings >= REQUIRED_CONSECUTIVE_EXIT_COUNT) {
                    Log.d(TAG, "Triggering RESTORE to normal")
                    currentActiveMosque = null
                    consecutiveOutsideReadings = 0
                    restorePhone()
                }
            }
        }
    }

    private fun silencePhone(mosqueName: String) {
        if (!isGpsEnabled()) {
            Log.d(TAG, "silencePhone skipped: GPS is OFF")
            return
        }

        val am = audioManager ?: return
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val currentMode = am.ringerMode
        if (currentMode == AudioManager.RINGER_MODE_NORMAL) {
            prefs.edit().putInt(KEY_PREVIOUS_RINGER_MODE, currentMode).apply()
        }
        prefs.edit().putBoolean(KEY_SILENCED_BY_SERVICE, true).apply()

        try {
            val targetMode = AudioManager.RINGER_MODE_VIBRATE
            if (am.ringerMode != targetMode) {
                am.ringerMode = targetMode
            }
            isCurrentlySilenced = true
            Log.d(TAG, "Phone successfully set to VIBRATE mode for: $mosqueName")

            updateNotification(
                title = "📳 Phone on Vibrate — $mosqueName",
                text = "Masjid ke range me hain. Mobile vibrate mode par laga diya gaya hai."
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error setting ringerMode to VIBRATE", e)
        }
    }

    private fun restorePhone() {
        val am = audioManager ?: return
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val wasSilencedByUs = prefs.getBoolean(KEY_SILENCED_BY_SERVICE, false)

        if (wasSilencedByUs || isCurrentlySilenced) {
            try {
                if (am.ringerMode != AudioManager.RINGER_MODE_NORMAL) {
                    am.ringerMode = AudioManager.RINGER_MODE_NORMAL
                }
                isCurrentlySilenced = false
                prefs.edit().putBoolean(KEY_SILENCED_BY_SERVICE, false).apply()
                Log.d(TAG, "Ringer successfully restored to NORMAL mode")

                if (isGpsEnabled()) {
                    updateNotification(
                        title = "🔔 Ringer Restored — Normal",
                        text = "Masjid se bahar aa gaye. Ringer wapas normal kar diya gaya."
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error restoring ringerMode to NORMAL", e)
            }
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "onTaskRemoved: App swiped away from recents, ensuring service stays active")
        try {
            val restartIntent = Intent(applicationContext, ServiceRestarterReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                applicationContext,
                101,
                restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmManager?.set(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + 500,
                pendingIntent
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling restart in onTaskRemoved", e)
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy: Cleaning up service")
        stopLocationListening()
        stopWatchdogTimer()
        try {
            if (ringerReceiver != null) {
                unregisterReceiver(ringerReceiver)
                ringerReceiver = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering ringerReceiver", e)
        }
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing WakeLock", e)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onProviderEnabled(provider: String) {
        Log.d(TAG, "Location provider enabled: $provider")
        if (isGpsEnabled()) {
            handleGpsEnabled()
        }
    }

    override fun onProviderDisabled(provider: String) {
        Log.d(TAG, "Location provider disabled: $provider")
        if (!isGpsEnabled()) {
            handleGpsDisabled()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
}
