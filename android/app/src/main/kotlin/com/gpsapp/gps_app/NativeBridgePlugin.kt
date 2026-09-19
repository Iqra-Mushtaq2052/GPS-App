package com.gpsapp.gps_app

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class NativeBridgePlugin : FlutterPlugin, MethodCallHandler {
    private val channelName = "com.gpsapp.gps_app/native_service"
    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, channelName)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context is null", null)
            return
        }

        val prefs = ctx.getSharedPreferences(MosqueForegroundService.PREFS_NAME, Context.MODE_PRIVATE)

        when (call.method) {
            "startNativeService" -> {
                val mosquesJson = call.argument<String>("mosquesJson")
                if (!mosquesJson.isNullOrEmpty()) {
                    prefs.edit().putString(MosqueForegroundService.KEY_MOSQUES_JSON, mosquesJson).apply()
                }
                prefs.edit().putBoolean(MosqueForegroundService.KEY_MONITORING_ENABLED, true).apply()
                MosqueForegroundService.startService(ctx)
                result.success(true)
            }
            "stopNativeService" -> {
                prefs.edit().putBoolean(MosqueForegroundService.KEY_MONITORING_ENABLED, false).apply()
                MosqueForegroundService.stopService(ctx)
                result.success(true)
            }
            "syncMosques" -> {
                val mosquesJson = call.argument<String>("mosquesJson")
                if (!mosquesJson.isNullOrEmpty()) {
                    prefs.edit().putString(MosqueForegroundService.KEY_MOSQUES_JSON, mosquesJson).apply()
                    val updateIntent = Intent(ctx, MosqueForegroundService::class.java).apply {
                        action = MosqueForegroundService.ACTION_UPDATE_MOSQUES
                    }
                    ctx.startService(updateIntent)
                }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
