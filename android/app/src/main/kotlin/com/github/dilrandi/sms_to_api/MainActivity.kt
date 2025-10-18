package com.github.dilrandi.sms_to_api


import android.Manifest
import android.app.AlertDialog
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.provider.Telephony
import android.util.Log
import android.widget.Toast
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val serviceChannelName = "com.github.dilrandi.sms_to_api_service/sms_forwarding"
    private val settingsChannelName = "com.github.dilrandi.sms_to_api/settings"
    private lateinit var serviceChannel: MethodChannel
    private lateinit var settingsChannel: MethodChannel
    private val prefsName = "sms_to_api_prefs"
    private val defaultPromptKey = "default_sms_prompt_shown"

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
            serviceChannel.invokeMethod("onServiceStatusChanged", "Running & Bound")
        }

        override fun onServiceDisconnected(arg0: ComponentName) {
            isBound = false
            smsForwardingService = null
            Log.d("MainActivity", "Service Disconnected: isBound=$isBound")
            // Inform Flutter about the status change
            serviceChannel.invokeMethod("onServiceStatusChanged", "Running & Unbound")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        serviceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, serviceChannelName)
        
        serviceChannel.setMethodCallHandler { call, result ->
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
                    serviceChannel.invokeMethod("onServiceStatusChanged", "Stopped")
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
                        serviceChannel.invokeMethod("onServiceStatusChanged", "Running & Unbound") // Service is still running in foreground
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

        settingsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, settingsChannelName)
        settingsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveSettings" -> {
                    val payload = call.argument<String>("payload")
                    if (payload.isNullOrEmpty()) {
                        result.error("INVALID_PAYLOAD", "Settings payload is required", null)
                    } else {
                        SecureSettingsBridge.write(applicationContext, payload)
                        result.success(true)
                    }
                }
                "loadSettings" -> {
                    result.success(SecureSettingsBridge.read(applicationContext))
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
        
        serviceChannel.invokeMethod("onServiceStatusChanged", "Running")
        result.success("Service started.")
    }

    override fun onResume() {
        super.onResume()
        // Request SMS permissions when the activity resumes
        requestSmsPermissions()
        ensureDefaultSmsApp()
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
                val permissionsArray = permissionsToRequest.toTypedArray()
                val needsRationale = permissionsArray.any {
                    ActivityCompat.shouldShowRequestPermissionRationale(this, it)
                }

                if (needsRationale) {
                    showSmsPermissionRationale(permissionsArray)
                } else {
                    ActivityCompat.requestPermissions(
                            this,
                            permissionsArray,
                            SMS_PERMISSION_REQUEST_CODE
                    )
                }
            } else {
                Log.d("MainActivity", "SMS permissions already granted.")
            }
        }
    }

    private fun showSmsPermissionRationale(permissions: Array<String>) {
        AlertDialog.Builder(this)
                .setTitle("SMS access required")
                .setMessage("SMS TO API needs SMS permissions to forward incoming messages to your configured endpoints.")
                .setPositiveButton(android.R.string.ok) { _, _ ->
                    ActivityCompat.requestPermissions(
                            this,
                            permissions,
                            SMS_PERMISSION_REQUEST_CODE
                    )
                }
                .setNegativeButton(android.R.string.cancel, null)
                .show()
    }

    private fun ensureDefaultSmsApp() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            val defaultPackage = Telephony.Sms.getDefaultSmsPackage(this)
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)

            if (defaultPackage == packageName) {
                // We are already default; allow future prompts if user switches away later.
                prefs.edit().remove(defaultPromptKey).apply()
                return
            }

            if (prefs.getBoolean(defaultPromptKey, false)) {
                return
            }

            prefs.edit().putBoolean(defaultPromptKey, true).apply()

            AlertDialog.Builder(this)
                    .setTitle("Set default SMS app")
                    .setMessage("To read SMS reliably, set SMS TO API as the default SMS application.")
                    .setPositiveButton(android.R.string.ok) { _, _ ->
                        val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
                        intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
                        startActivity(intent)
                    }
                    .setNegativeButton(android.R.string.cancel, null)
                    .show()
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
                        serviceChannel.invokeMethod("onServiceStatusChanged", result as String)
                    }
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        serviceChannel.invokeMethod("onServiceStatusChanged", "Error: $errorMessage")
                    }
                    override fun notImplemented() {
                        serviceChannel.invokeMethod("onServiceStatusChanged", "Not Implemented")
                    }
                })
                } else {
                    Log.w("MainActivity", "POST_NOTIFICATIONS permission denied.")
                    serviceChannel.invokeMethod("onServiceStatusChanged", "Permission Denied, Service Not Started")
                }
            }
            SMS_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    Log.d("MainActivity", "SMS permissions granted.")
                } else {
                    Log.w("MainActivity", "SMS permissions denied. SMS reception may not work.")
                    Toast.makeText(
                            this,
                            "SMS permissions were denied. Incoming messages may not be forwarded.",
                            Toast.LENGTH_LONG
                    ).show()
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
