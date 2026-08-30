package com.gpsapp.gps_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

/**
 * Notifies Dart, in real time, whenever the user (or the OS) changes the
 * ringer/DND state — via the two system broadcasts Android fires for this:
 * AudioManager.RINGER_MODE_CHANGED_ACTION for the classic ringer knob, and
 * NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED for DND-tile
 * toggles that can bypass the ringer API on some OEM skins.
 *
 * This exists so the proximity engine can re-apply silent mode within
 * roughly a second of the user manually un-silencing while still inside a
 * masjid, instead of only re-checking on the next GPS fix.
 */
class RingerModeWatcher : FlutterPlugin, EventChannel.StreamHandler {
    private val channelName = "com.gpsapp.gps_app/ringer_watcher"
    private var channel: EventChannel? = null
    private var receiver: BroadcastReceiver? = null
    private var applicationContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = EventChannel(binding.binaryMessenger, channelName)
        channel?.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setStreamHandler(null)
        channel = null
        unregisterReceiver()
        applicationContext = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        val context = applicationContext ?: return
        val filter = IntentFilter().apply {
            addAction(AudioManager.RINGER_MODE_CHANGED_ACTION)
            addAction(NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED)
        }
        val newReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                events?.success(intent?.action)
            }
        }
        // RECEIVER_NOT_EXPORTED: these are system broadcasts we only need to
        // observe ourselves, not ones another app should be able to spoof
        // into us — matches Android 13+'s required exported-state flag.
        ContextCompat.registerReceiver(
            context,
            newReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        receiver = newReceiver
    }

    override fun onCancel(arguments: Any?) {
        unregisterReceiver()
    }

    private fun unregisterReceiver() {
        val context = applicationContext
        val current = receiver
        if (context != null && current != null) {
            context.unregisterReceiver(current)
        }
        receiver = null
    }
}
