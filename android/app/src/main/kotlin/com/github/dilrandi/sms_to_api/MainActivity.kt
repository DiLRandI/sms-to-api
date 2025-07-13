package com.github.dilrandi.sms_to_api

import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import android.content.ServiceConnection
import android.content.ComponentName
import android.os.IBinder
import android.util.Log
import android.content.Intent
import android.content.Context

class MainActivity : FlutterActivity(){
 // Define the same channel name as in Flutter
    private val CHANNEL = "com.github.dilrandi.sms_to_api/counter"

    private var counterService: CounterService? = null
    private var isBound = false
    private lateinit var channel: MethodChannel

    // Defines callbacks for service binding, unbinding, and re-binding.
    private val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            // We've bound to LocalService, cast the IBinder and get LocalService instance
            val binder = service as CounterService.CounterBinder
            counterService = binder.getService()
            isBound = true
            Log.d("MainActivity", "Service Bound: isBound=$isBound")
            
            // Inform Flutter about the status change
            channel.invokeMethod("onServiceStatusChanged", "Bound")
        }

        override fun onServiceDisconnected(arg0: ComponentName) {
            isBound = false
            counterService = null
            Log.d("MainActivity", "Service Disconnected: isBound=$isBound")
            // Inform Flutter about the status change
            channel.invokeMethod("onServiceStatusChanged", "Disconnected")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "bindCounterService" -> {
                    if (!isBound) {
                        val intent = Intent(this, CounterService::class.java)
                        // BIND_AUTO_CREATE creates the service if it's not already running
                        bindService(intent, connection, Context.BIND_AUTO_CREATE)
                        result.success("Binding...")
                    } else {
                        result.success("Already Bound")
                    }
                }
                "unbindCounterService" -> {
                    if (isBound) {
                        unbindService(connection)
                        isBound = false
                        counterService = null
                        result.success("Unbound")
                    } else {
                        result.success("Not Bound")
                    }
                }
                "incrementCounter" -> {
                    if (isBound && counterService != null) {
                        val newCounterValue = counterService!!.incrementCounter()
                        result.success(newCounterValue)
                    } else {
                        result.error("UNBOUND_SERVICE", "Service is not bound or null", null)
                    }
                }
                "getCounter" -> {
                    if (isBound && counterService != null) {
                        val currentCounterValue = counterService!!.getCounter()
                        result.success(currentCounterValue)
                    } else {
                        result.error("UNBOUND_SERVICE", "Service is not bound or null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Ensure the service is unbound when the activity is destroyed to prevent leaks
        if (isBound) {
            unbindService(connection)
            isBound = false
        }
    }
}

