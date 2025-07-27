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

data class AppSettings(
        val url: String?,
        val apiKey: String?,
        val authHeaderName: String,
        val phoneNumbers: List<String>
)

class SmsForwardingService : Service() {

    private val TAG = "SmsForwardingService"
    private lateinit var logManager: LogManager

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
        sendToApi("TEST_SENDER", "This is a test message for API verification - triggered manually")
    }

    override fun onBind(intent: Intent?): IBinder? {
        logManager.logDebug(TAG, "SmsForwardingService: onBind()")
        return binder // Return the binder for clients (MainActivity) to interact
    }

    override fun onUnbind(intent: Intent?): Boolean {
        logManager.logDebug(TAG, "SmsForwardingService: onUnbind()")
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
            val smsSender = intent?.getStringExtra("sms_sender")
            val smsBody = intent?.getStringExtra("sms_body")

            logManager.logInfo(TAG, "Received SMS from $smsSender with body: $smsBody")
            sendToApi(smsSender, smsBody) // Send SMS data to API
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

        // Return START_STICKY to ensure the service is restarted if killed by the system
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

    private fun sendToApi(smsSender: String?, smsBody: String?) {
        if (smsSender == null || smsBody == null) {
            logManager.logWarning(TAG, "SMS sender or body is null, skipping API call")
            return
        }

        val settings = getStoredSettings()
        if (settings.url.isNullOrEmpty() || settings.apiKey.isNullOrEmpty()) {
            logManager.logWarning(TAG, "API URL or API Key not configured, skipping API call")
            return
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
                return
            }

            logManager.logInfo(
                    TAG,
                    "SMS sender '$smsSender' matches configured phone numbers. Proceeding with API call"
            )
        } else {
            logManager.logInfo(TAG, "No phone numbers configured, sending all SMS to API")
        }

        logManager.logInfo(TAG, "Sending SMS to API: sender=$smsSender, body=$smsBody")

        // Use Kotlin's built-in HttpURLConnection for a simple HTTP POST
        Thread {
                    try {
                        val apiUrl = java.net.URL(settings.url)
                        val connection = apiUrl.openConnection() as java.net.HttpURLConnection
                        connection.requestMethod = "POST"
                        connection.setRequestProperty("Content-Type", "application/json")
                        connection.setRequestProperty(
                                settings.authHeaderName,
                                "${settings.apiKey}"
                        )
                        connection.doOutput = true
                        // These numbers are set because the API will be a lambda, and it will not
                        // be provisioned,
                        // therefore keep some time for cold starts
                        connection.connectTimeout = 10000 // Set timeout for connection
                        connection.readTimeout = 10000 // Set timeout for reading response

                        val jsonBody = JSONObject()
                        jsonBody.put("sender", smsSender)
                        jsonBody.put("body", smsBody)

                        val outputStream = connection.outputStream
                        outputStream.write(jsonBody.toString().toByteArray(Charsets.UTF_8))
                        outputStream.flush()
                        outputStream.close()

                        val responseCode = connection.responseCode
                        logManager.logInfo(TAG, "API Response Code: $responseCode")
                        connection.inputStream.close()
                        connection.disconnect()
                    } catch (e: Exception) {
                        logManager.logError(TAG, "Error sending SMS to API: ${e.message}", e)
                    }
                }
                .start()
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

                AppSettings(url, apiKey, authHeaderName, phoneNumbers)
            } catch (e: Exception) {
                logManager.logError(TAG, "Error parsing settings JSON: ${e.message}", e)
                AppSettings(null, null, "Authorization", emptyList())
            }
        } else {
            logManager.logDebug(TAG, "No settings found in SharedPreferences")
            AppSettings(null, null, "Authorization", emptyList())
        }
    }

    companion object {
        const val CHANNEL_ID = "SmsForwardingServiceChannel"
        const val NOTIFICATION_ID = 101 // Unique ID for your notification
        const val ACTION_FORWARD_SMS_TO_API = "com.github.dilrandi.sms_to_api.FORWARD_SMS_TO_API"
    }
}
