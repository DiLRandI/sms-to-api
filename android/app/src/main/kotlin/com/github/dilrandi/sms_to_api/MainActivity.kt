package com.github.dilrandi.sms_to_api


import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.role.RoleManager
import android.content.ActivityNotFoundException
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
    private var defaultPromptInFlight = false
    private var defaultPromptDialog: AlertDialog? = null

    private var smsForwardingService: SmsForwardingService? = null
    private var isBound = false // To track if the activity is bound to the service

    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 102
    private val SMS_PERMISSION_REQUEST_CODE = 103 // New request code for SMS permissions
    private val ROLE_REQUEST_CODE = 104

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
        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        if (isCurrentDefaultSmsApp()) {
            prefs.edit().remove(defaultPromptKey).apply()
            defaultPromptInFlight = false
            return
        }

        if (defaultPromptInFlight) {
            return
        }

        // Clear stale flag so we can re-prompt if a previous attempt failed.
        if (prefs.getBoolean(defaultPromptKey, false)) {
            prefs.edit().remove(defaultPromptKey).apply()
        }

        if (tryRequestDefaultSmsRole()) {
            return
        }

        showLegacyDefaultSmsPrompt()
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

    override fun onPause() {
        super.onPause()
        defaultPromptDialog?.setOnDismissListener(null)
        defaultPromptDialog?.dismiss()
        defaultPromptDialog = null
        defaultPromptInFlight = false
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == ROLE_REQUEST_CODE) {
            defaultPromptInFlight = false
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            if (isCurrentDefaultSmsApp()) {
                prefs.edit().remove(defaultPromptKey).apply()
            } else {
                prefs.edit().remove(defaultPromptKey).apply()
                val fallbackMessage =
                        if (resultCode == Activity.RESULT_OK) {
                            "Your device blocked SMS TO API from taking over automatically. Tap OK to open the system picker and finish setting it as the default SMS app."
                        } else {
                            "SMS TO API must be the default SMS application to capture and forward new messages. Tap OK to open the system picker."
                        }
                showLegacyDefaultSmsPrompt(fallbackMessage)
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
        defaultPromptDialog = null
        defaultPromptInFlight = false
    }

    private fun isCurrentDefaultSmsApp(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_SMS)) {
                if (roleManager.isRoleHeld(RoleManager.ROLE_SMS)) {
                    return true
                }
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            val defaultPackage = Telephony.Sms.getDefaultSmsPackage(this)
            if (defaultPackage == packageName) {
                return true
            }
        }
        return false
    }

    private fun canShowPrompt(): Boolean {
        if (isFinishing) return false
        return !(Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1 && isDestroyed)
    }

    @Suppress("DEPRECATION")
    private fun tryRequestDefaultSmsRole(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return false
        }
        val roleManager = getSystemService(RoleManager::class.java) ?: return false
        if (!roleManager.isRoleAvailable(RoleManager.ROLE_SMS)) {
            return false
        }

        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        return try {
            defaultPromptInFlight = true
            prefs.edit().putBoolean(defaultPromptKey, true).apply()
            val roleIntent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
            startActivityForResult(roleIntent, ROLE_REQUEST_CODE)
            true
        } catch (e: ActivityNotFoundException) {
            Log.w("MainActivity", "ROLE_SMS intent unavailable, falling back to legacy prompt", e)
            defaultPromptInFlight = false
            prefs.edit().remove(defaultPromptKey).apply()
            false
        } catch (e: SecurityException) {
            Log.w("MainActivity", "ROLE_SMS request blocked by platform, falling back", e)
            defaultPromptInFlight = false
            prefs.edit().remove(defaultPromptKey).apply()
            false
        }
    }

    private fun showLegacyDefaultSmsPrompt(messageOverride: String? = null) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            return
        }

        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val promptMessage =
                messageOverride
                        ?: "SMS TO API must be the default SMS application to capture and forward new messages."

        val prompt =
                AlertDialog.Builder(this)
                        .setTitle("Set default SMS app")
                        .setMessage(promptMessage)
                        .setPositiveButton(android.R.string.ok) { _, _ ->
                            launchDefaultSmsSettings()
                        }
                        .setNegativeButton(android.R.string.cancel) { _, _ ->
                            Toast.makeText(
                                            applicationContext,
                                            "SMS forwarding stays inactive until SMS TO API is set as the default app.",
                                            Toast.LENGTH_LONG
                                    )
                                    .show()
                        }
                        .create()

        prompt.setOnDismissListener {
            defaultPromptInFlight = false
            prefs.edit().remove(defaultPromptKey).apply()
            defaultPromptDialog = null
        }

        if (canShowPrompt()) {
            defaultPromptInFlight = true
            prefs.edit().putBoolean(defaultPromptKey, true).apply()
            defaultPromptDialog = prompt
            prompt.show()
        } else {
            defaultPromptDialog = null
        }
    }

    private fun launchDefaultSmsSettings() {
        val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT).apply {
            putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
        }
        try {
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            Log.w("MainActivity", "ACTION_CHANGE_DEFAULT unavailable on this device", e)
            Toast.makeText(
                            applicationContext,
                            "Open system settings and set SMS TO API as the default SMS app manually.",
                            Toast.LENGTH_LONG
                    )
                    .show()
        } catch (e: SecurityException) {
            Log.w("MainActivity", "ACTION_CHANGE_DEFAULT blocked by platform policies", e)
            Toast.makeText(
                            applicationContext,
                            "Device policies are blocking the default SMS change. Adjust security settings and retry.",
                            Toast.LENGTH_LONG
                    )
                    .show()
        }
    }
}
