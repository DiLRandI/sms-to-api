package com.github.dilrandi.sms_to_api


import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Build
import android.os.IBinder
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.app.ActivityCompat
import android.content.pm.PackageManager
import android.Manifest

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.github.dilrandi.sms_to_api_service/sms_forwarding"
    private lateinit var channel: MethodChannel

    private var smsForwardingService: SmsForwardingService? = null
    private var isBound = false // To track if the activity is bound to the service

    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 102
    private val SMS_PERMISSION_REQUEST_CODE = 103 // New request code for SMS permissions

    // Defines callbacks for service binding, unbinding, and re-binding.
    private val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            // We've bound to SmsForwardingService, cast the IBinder and get SmsForwardingService instance
            val binder = service as SmsForwardingService.SmsForwardingBinder
            smsForwardingService = binder.getService()
            isBound = true
            
            Log.d("MainActivity", "Service Bound: isBound=$isBound")
            // Inform Flutter about the status change
            channel.invokeMethod("onServiceStatusChanged", "Running & Bound")
        }

        override fun onServiceDisconnected(arg0: ComponentName) {
            isBound = false
            smsForwardingService = null
            Log.d("MainActivity", "Service Disconnected: isBound=$isBound")
            // Inform Flutter about the status change
            channel.invokeMethod("onServiceStatusChanged", "Running & Unbound")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startSmsForwardingService" -> {
                    // Request notification permission before starting foreground service (Android 13+)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_REQUEST_CODE
                            )
                            // We return a pending state, and will start service in onRequestPermissionsResult
                            result.success("Permission requested. Service will start after permission.")
                            return@setMethodCallHandler
                        }
                    }
                    startSmsForwardingServiceInternal(result)
                }
                "stopSmsForwardingService" -> {
                    val intent = Intent(this, SmsForwardingService::class.java)
                    stopService(intent)
                    // If the activity is bound, unbind it as the service is stopping
                    if (isBound) {
                        unbindService(connection)
                        isBound = false
                        smsForwardingService = null
                    }
                    channel.invokeMethod("onServiceStatusChanged", "Stopped")
                    result.success("Service stopped.")
                }
                "bindSmsForwardingService" -> {
                    if (!isBound) {
                        val intent = Intent(this, SmsForwardingService::class.java)
                        // BIND_AUTO_CREATE creates the service if it's not already running
                        // and binds to it. If it's already running, it just binds.
                        bindService(intent, connection, Context.BIND_AUTO_CREATE)
                        result.success("Binding...")
                    } else {
                        result.success("Already Bound")
                    }
                }
                "unbindSmsForwardingService" -> {
                    if (isBound) {
                        unbindService(connection)
                        isBound = false
                        smsForwardingService = null
                        result.success("Unbound")
                        channel.invokeMethod("onServiceStatusChanged", "Running & Unbound") // Service is still running in foreground
                    } else {
                        result.success("Not Bound")
                    }
                }
                "testApiCall" -> {
                    if (smsForwardingService != null) {
                        smsForwardingService!!.testApiCall()
                        result.success("Test API call initiated")
                    } else {
                        result.error("SERVICE_NOT_AVAILABLE", "SMS Forwarding Service is not available. Please start and bind the service first.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startSmsForwardingServiceInternal(result: MethodChannel.Result) {
        val intent = Intent(this, SmsForwardingService::class.java)
        // For Android O and above, you must use startForegroundService()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        
        // Also bind to the service to establish the logs channel connection
        if (!isBound) {
            bindService(intent, connection, Context.BIND_AUTO_CREATE)
        }
        
        channel.invokeMethod("onServiceStatusChanged", "Running")
        result.success("Service started.")
    }

    override fun onResume() {
        super.onResume()
        // Request SMS permissions when the activity resumes
        requestSmsPermissions()
    }

    private fun requestSmsPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val permissionsToRequest = mutableListOf<String>()
            if (checkSelfPermission(Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.RECEIVE_SMS)
            }
            if (checkSelfPermission(Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_SMS)
            }

            if (permissionsToRequest.isNotEmpty()) {
                ActivityCompat.requestPermissions(
                    this,
                    permissionsToRequest.toTypedArray(),
                    SMS_PERMISSION_REQUEST_CODE
                )
            } else {
                Log.d("MainActivity", "SMS permissions already granted.")
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            NOTIFICATION_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d("MainActivity", "POST_NOTIFICATIONS permission granted.")
                    // If permission granted, try starting the service again
                   startSmsForwardingServiceInternal(object : MethodChannel.Result {
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
            SMS_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    Log.d("MainActivity", "SMS permissions granted.")
                } else {
                    Log.w("MainActivity", "SMS permissions denied. SMS reception may not work.")
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Ensure the service is unbound when the activity is destroyed to prevent leaks
        if (isBound) {
            unbindService(connection)
            isBound = false
            smsForwardingService = null
        }
    }
}