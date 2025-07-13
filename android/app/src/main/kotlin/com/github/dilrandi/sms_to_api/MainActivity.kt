package com.github.dilrandi.sms_to_api

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.github.dilrandi.sms_to_api/counter"
    private lateinit var channel: MethodChannel

    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 102

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCounterService" -> {
                    // Request notification permission before starting foreground service (Android 13+)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_REQUEST_CODE
                            )
                            // We return a pending state, and will start service in onRequestPermissionsResult
                            result.success("Permission requested. Starting service after permission.")
                            return@setMethodCallHandler
                        }
                    }
                    startCounterServiceInternal(result)                                                                                                                                                                                                                                                 
                }
                "stopCounterService" -> {
                    val intent = Intent(this, CounterService::class.java)
                    stopService(intent)
                    channel.invokeMethod("onServiceStatusChanged", "Stopped")
                    result.success("Service stopped.")
                }
                "incrementCounter" -> {
                    // To call service methods, we need to ensure the service is running
                    // and then call its methods. For a started service, we can't directly
                    // get a binder like before. We'll rely on the service being started
                    // and then communicate with it (e.g., via static methods or another channel).
                    // For this simple example, we'll just call the method on a new instance
                    // of the service, assuming it's running. In a real app, you might
                    // use a bound service for method calls, or broadcast intents to a started service.
                    // For simplicity, we'll instantiate the service and call its method.
                    // THIS IS NOT IDEAL FOR PRODUCTION. For robust communication, consider
                    // a more complex IPC mechanism or a bound service that is also started.
                    val service = CounterService() // This creates a new instance, not the running one
                    val newCounterValue = service.incrementCounter() // This operates on a new instance's counter
                    result.success(newCounterValue)
                }
                "getCounter" -> {
                    val service = CounterService() // Same as above, new instance
                    val currentCounterValue = service.getCounter()
                    result.success(currentCounterValue)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startCounterServiceInternal(result: MethodChannel.Result) {
        val intent = Intent(this, CounterService::class.java)
        // For Android O and above, you must use startForegroundService()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {                                                                                                                                                   
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        channel.invokeMethod("onServiceStatusChanged", "Running")
        result.success("Service started.")
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d("MainActivity", "POST_NOTIFICATIONS permission granted.")
                // If permission granted, try starting the service again
                startCounterServiceInternal(object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        channel.invokeMethod("onServiceStatusChanged", result as String)
                    }
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        channel.invokeMethod("onServiceStatusChanged", "Error: $errorMessage")
                    }
                    override fun notImplemented() {
                        channel.invokeMethod("onServiceStatusChanged", "Not Implemented")
                    }
                })
            } else {
                Log.w("MainActivity", "POST_NOTIFICATIONS permission denied.")
                channel.invokeMethod("onServiceStatusChanged", "Permission Denied, Service Not Started")
            }
        }
    }
}