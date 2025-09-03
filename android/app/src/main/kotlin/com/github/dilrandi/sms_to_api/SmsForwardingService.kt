package com.github.dilrandi.sms_to_api

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Binder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONObject

data class Endpoint(
        val id: String,
        val name: String,
        val url: String,
        val apiKey: String,
        val active: Boolean,
        val authHeaderName: String = "Authorization"
)

data class AppSettings(
        val url: String?, // legacy
        val apiKey: String?, // legacy
        val authHeaderName: String,
        val phoneNumbers: List<String>,
        val endpoints: List<Endpoint>
)

class SmsForwardingService : Service() {

    private val TAG = "SmsForwardingService"
    private lateinit var logManager: LogManager
    @Volatile private var boundClients: Int = 0

    // Binder given to clients for local interaction
    private val binder = SmsForwardingBinder()

    /**
     * Class used for the client Binder. Because we know this service always runs in the same
     * process as its clients, we don't need to deal with IPC.
     */
    inner class SmsForwardingBinder : Binder() {
        // Return this instance of SmsForwardingService so clients can call public methods
        fun getService(): SmsForwardingService = this@SmsForwardingService
    }

    // Public method to test API with sample data
    fun testApiCall() {
        logManager.logInfo(TAG, "Manual API test initiated")
        // Call the private sendToApi method for testing
        sendToApi(
                "TEST_SENDER",
                "This is a test message for API verification - triggered manually",
                1
        )
    }

    override fun onBind(intent: Intent?): IBinder? {
        logManager.logDebug(TAG, "SmsForwardingService: onBind()")
        boundClients += 1
        return binder // Return the binder for clients (MainActivity) to interact
    }

    override fun onUnbind(intent: Intent?): Boolean {
        logManager.logDebug(TAG, "SmsForwardingService: onUnbind()")
        if (boundClients > 0) boundClients -= 1
        // Returning true here means onRebind() will be called if clients bind again
        return true
    }

    override fun onRebind(intent: Intent?) {
        logManager.logDebug(TAG, "SmsForwardingService: onRebind()")
        super.onRebind(intent)
    }

    override fun onCreate() {
        super.onCreate()
        logManager = LogManager(this)
        logManager.logInfo(TAG, "SmsForwardingService: onCreate() - Service starting up")
        logManager.logDebug(TAG, "Initializing SMS forwarding service")
        createNotificationChannel() // Create notification channel for Android O+
        logManager.logInfo(TAG, "SMS forwarding service initialization completed successfully")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        logManager.logDebug(
                TAG,
                "SmsForwardingService: onStartCommand() - Intent Action: ${intent?.action}"
        )

        // Check if the intent is from SMSReceiver to forward SMS
        if (intent?.action == ACTION_FORWARD_SMS_TO_API) {
            val smsSender = intent.getStringExtra("sms_sender")
            val smsBody = intent.getStringExtra("sms_body")
            val smsPartsCount = intent.getIntExtra("sms_parts_count", 1)
            val autoStop = intent.getBooleanExtra("auto_stop", false)

            // Truncate body in logs for readability/privacy; keep full body for API payload
            val safeBody = (smsBody ?: "").let { if (it.length > 160) it.take(160) + "…" else it }
            if (smsPartsCount > 1) {
                logManager.logInfo(
                        TAG,
                        "Received multi-part SMS ($smsPartsCount parts) from $smsSender with body: $safeBody"
                )
            } else {
                logManager.logInfo(TAG, "Received SMS from $smsSender with body: $safeBody")
            }
            // Send SMS data to API(s); if no work is started, stop early to avoid lingering service
            val workStarted = sendToApi(smsSender, smsBody, smsPartsCount, autoStop, startId)
            if (!workStarted && autoStop && boundClients == 0) {
                logManager.logDebug(TAG, "No work started; stopping service early (startId=$startId)")
                try {
                    stopSelf(startId)
                } catch (_: Exception) {}
                return START_NOT_STICKY
            }
        }

        // Build the notification for the foreground service
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent =
                PendingIntent.getActivity(
                        this,
                        0,
                        notificationIntent,
                        PendingIntent.FLAG_IMMUTABLE // Use FLAG_IMMUTABLE for security
                )

        val notification =
                NotificationCompat.Builder(this, CHANNEL_ID)
                        .setContentTitle("SMS Forwarding Service")
                        .setContentText("Monitoring SMS messages for API forwarding")
                        .setSmallIcon(android.R.drawable.ic_dialog_email) // Use built-in email icon
                        .setContentIntent(pendingIntent)
                        .setPriority(
                                NotificationCompat.PRIORITY_LOW
                        ) // Low priority to be less intrusive
                        .build()

        // Start the service in the foreground
        startForeground(NOTIFICATION_ID, notification)

        // Keep current behavior but consider NOT_STICKY if not intended to run persistently
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        logManager.logInfo(TAG, "SmsForwardingService: onDestroy()")
        // Clean up resources if any (e.g., stop threads, release sensors)
    }

    // --- Notification Helper Methods ---

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel =
                    NotificationChannel(
                            CHANNEL_ID,
                            "SMS Forwarding Service Channel",
                            NotificationManager.IMPORTANCE_LOW // Importance LOW for less intrusive
                            // notification
                            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun sendToApi(
            smsSender: String?,
            smsBody: String?,
            smsPartsCount: Int = 1,
            autoStopWhenDone: Boolean = false,
            serviceStartId: Int = 0
    ): Boolean {
        if (smsSender == null || smsBody == null) {
            logManager.logWarning(TAG, "SMS sender or body is null, skipping API call")
            return false
        }

        val settings = getStoredSettings()

        // Build list of active endpoints (prefer new multi-endpoint config; fallback to legacy)
        val activeEndpoints: List<Endpoint> =
                if (settings.endpoints.isNotEmpty()) settings.endpoints.filter { it.active }
                else if (!settings.url.isNullOrEmpty() && !settings.apiKey.isNullOrEmpty())
                        listOf(
                                Endpoint(
                                        id = "legacy",
                                        name = "Default",
                                        url = settings.url!!,
                                        apiKey = settings.apiKey!!,
                                        active = true,
                                        authHeaderName = settings.authHeaderName
                                )
                        )
                else emptyList()

        if (activeEndpoints.isEmpty()) {
            logManager.logWarning(TAG, "No active API endpoints configured, skipping API call")
            return false
        }

        // Check if phone numbers are configured and if sender matches any of them
        if (settings.phoneNumbers.isNotEmpty()) {
            val senderMatches =
                    settings.phoneNumbers.any { configuredNumber ->
                        // Check for exact match or if the sender contains the configured number
                        smsSender == configuredNumber ||
                                smsSender.contains(configuredNumber) ||
                                configuredNumber.contains(smsSender)
                    }

            if (!senderMatches) {
                logManager.logDebug(
                        TAG,
                        "SMS sender '$smsSender' does not match any configured phone numbers: ${settings.phoneNumbers}. Skipping API call"
                )
                return false
            }

            logManager.logInfo(
                    TAG,
                    "SMS sender '$smsSender' matches configured phone numbers. Proceeding with API call"
            )
        } else {
            logManager.logInfo(TAG, "No phone numbers configured, sending all SMS to API")
        }

        val messageInfo = if (smsPartsCount > 1) "multi-part SMS ($smsPartsCount parts)" else "SMS"
        val safeBodyForSendLog =
                (smsBody ?: "").let { if (it.length > 160) it.take(160) + "…" else it }
        logManager.logInfo(
                TAG,
                "Sending $messageInfo to ${activeEndpoints.size} API endpoint(s): sender=$smsSender, body=$safeBodyForSendLog"
        )

        // Use Kotlin's built-in HttpURLConnection for a simple HTTP POST
        Thread {
                    try {
                        for (endpoint in activeEndpoints) {
                            try {
                                val apiUrl = java.net.URL(endpoint.url)
                                val connection =
                                        apiUrl.openConnection() as java.net.HttpURLConnection
                                connection.requestMethod = "POST"
                                connection.setRequestProperty("Content-Type", "application/json")
                                val headerName =
                                        if (endpoint.authHeaderName.isNotEmpty()) endpoint.authHeaderName
                                        else settings.authHeaderName
                                connection.setRequestProperty(headerName, endpoint.apiKey)
                                connection.doOutput = true
                                connection.connectTimeout = 10000
                                connection.readTimeout = 10000

                                val jsonBody = JSONObject()
                                jsonBody.put("sender", smsSender)
                                jsonBody.put("body", smsBody)
                                jsonBody.put("parts_count", smsPartsCount)
                                jsonBody.put("is_multipart", smsPartsCount > 1)
                                jsonBody.put("endpoint_name", endpoint.name)

                                val outputStream = connection.outputStream
                                outputStream.write(jsonBody.toString().toByteArray(Charsets.UTF_8))
                                outputStream.flush()
                                outputStream.close()

                                val responseCode = connection.responseCode
                                when {
                                    responseCode >= 500 ->
                                            logManager.logError(
                                                    TAG,
                                                    "${endpoint.name}: server error ($responseCode)"
                                            )
                                    responseCode >= 400 ->
                                            logManager.logWarning(
                                                    TAG,
                                                    "${endpoint.name}: client error ($responseCode)"
                                            )
                                    else ->
                                            logManager.logInfo(
                                                    TAG,
                                                    "${endpoint.name}: request succeeded ($responseCode)"
                                            )
                                }
                                try {
                                    if (responseCode >= 400) {
                                        connection.errorStream?.close()
                                    } else {
                                        connection.inputStream?.close()
                                    }
                                } catch (_: Exception) {}
                                connection.disconnect()
                            } catch (e: Exception) {
                                logManager.logError(
                                        TAG,
                                        "${endpoint.name}: error sending SMS: ${e.message}",
                                        e
                                )
                            }
                        }
                    } finally {
                        if (autoStopWhenDone && boundClients == 0) {
                            try {
                                stopForeground(true)
                            } catch (_: Exception) {}
                            try {
                                stopSelf(serviceStartId)
                            } catch (_: Exception) {}
                        }
                    }
                }
                .start()
        return true
    }

    private fun getStoredSettings(): AppSettings {
        val sharedPrefs: SharedPreferences =
                getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val settingsJson = sharedPrefs.getString("flutter.settings_data", null)

        return if (settingsJson != null) {
            try {
                val jsonObject = JSONObject(settingsJson)
                val url =
                        if (jsonObject.optString("url", "").isNotEmpty())
                                jsonObject.optString("url", "")
                        else null
                val apiKey =
                        if (jsonObject.optString("apiKey", "").isNotEmpty())
                                jsonObject.optString("apiKey", "")
                        else null
                val authHeaderName = jsonObject.optString("authHeaderName", "Authorization")
                val phoneNumbers = mutableListOf<String>()

                // Parse phone numbers array if it exists
                if (jsonObject.has("phoneNumbers")) {
                    val phoneNumbersArray = jsonObject.getJSONArray("phoneNumbers")
                    for (i in 0 until phoneNumbersArray.length()) {
                        phoneNumbers.add(phoneNumbersArray.getString(i))
                    }
                }

                // Parse endpoints array if it exists
                val endpoints = mutableListOf<Endpoint>()
                if (jsonObject.has("endpoints")) {
                    val arr = jsonObject.getJSONArray("endpoints")
                    for (i in 0 until arr.length()) {
                        val o = arr.getJSONObject(i)
                        val id = o.optString("id", i.toString())
                        val name = o.optString("name", "Endpoint ${i + 1}")
                        val epUrl = o.optString("url", "")
                        val epKey = o.optString("apiKey", "")
                        val active = o.optBoolean("active", true)
                        val header = o.optString("authHeaderName", "Authorization")
                        if (epUrl.isNotEmpty() && epKey.isNotEmpty()) {
                            endpoints.add(Endpoint(id, name, epUrl, epKey, active, header))
                        }
                    }
                }

                AppSettings(url, apiKey, authHeaderName, phoneNumbers, endpoints)
            } catch (e: Exception) {
                logManager.logError(TAG, "Error parsing settings JSON: ${e.message}", e)
                AppSettings(null, null, "Authorization", emptyList(), emptyList())
            }
        } else {
            logManager.logDebug(TAG, "No settings found in SharedPreferences")
            AppSettings(null, null, "Authorization", emptyList(), emptyList())
        }
    }

    companion object {
        const val CHANNEL_ID = "SmsForwardingServiceChannel"
        const val NOTIFICATION_ID = 101 // Unique ID for your notification
        const val ACTION_FORWARD_SMS_TO_API = "com.github.dilrandi.sms_to_api.FORWARD_SMS_TO_API"
    }
}
