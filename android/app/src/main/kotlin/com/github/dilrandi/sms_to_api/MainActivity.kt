package com.github.dilrandi.sms_to_api

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "sms_forwarding_service"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startSmsService()
                    result.success(true)
                }
                "stopService" -> {
                    stopSmsService()
                    result.success(true)
                }
                "isServiceRunning" -> {
                    val isRunning = isServiceRunning()
                    result.success(isRunning)
                }
                "requestBatteryOptimization" -> {
                    requestBatteryOptimization()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startSmsService() {
        val serviceIntent = Intent(this, SmsForwardingService::class.java)
        serviceIntent.action = SmsForwardingService.ACTION_START_SERVICE
        startForegroundService(serviceIntent)
    }

    private fun stopSmsService() {
        val serviceIntent = Intent(this, SmsForwardingService::class.java)
        serviceIntent.action = SmsForwardingService.ACTION_STOP_SERVICE
        startService(serviceIntent)
    }

    private fun isServiceRunning(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in activityManager.getRunningServices(Integer.MAX_VALUE)) {
            if (SmsForwardingService::class.java.name == service.service.className) {
                return true
            }
        }
        return false
    }

    private fun requestBatteryOptimization() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        }
    }
}
