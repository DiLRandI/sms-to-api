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
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

class CounterService : Service() {

    private val TAG = "CounterService"
    private var counter: Int = 0 // The counter state

    // Binder given to clients for local interaction
    private val binder = CounterBinder()

    /**
     * Class used for the client Binder. Because we know this service always runs in the same
     * process as its clients, we don't need to deal with IPC.
     */
    inner class CounterBinder : Binder() {
        // Return this instance of CounterService so clients can call public methods
        fun getService(): CounterService = this@CounterService
    }

    override fun onBind(intent: Intent?): IBinder? {
        Log.d(TAG, "CounterService: onBind()")
        return binder // Return the binder for clients (MainActivity) to interact
    }

    override fun onUnbind(intent: Intent?): Boolean {
        Log.d(TAG, "CounterService: onUnbind()")
        // Returning true here means onRebind() will be called if clients bind again
        return true
    }

    override fun onRebind(intent: Intent?) {
        Log.d(TAG, "CounterService: onRebind()")
        super.onRebind(intent)
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "CounterService: onCreate()")
        createNotificationChannel() // Create notification channel for Android O+
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "CounterService: onStartCommand() - Intent Action: ${intent?.action}")

        // Check if the intent is from SMSReceiver to increment counter
        if (intent?.action == ACTION_INCREMENT_COUNTER_FROM_SMS) {
            val smsSender = intent.getStringExtra("sms_sender")
            val smsBody = intent.getStringExtra("sms_body")

            sendToApi(smsSender, smsBody) // Send SMS data to API

            incrementCounter()
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
                        .setContentTitle("Counter Service Running")
                        .setContentText("Current Count: $counter") // You can update this later
                        .setSmallIcon(R.drawable.ic_stat_name) // Use a proper icon for your app
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
        Log.d(TAG, "CounterService: onDestroy()")
        // Clean up resources if any (e.g., stop threads, release sensors)
    }

    /**
     * Public method to increment the counter. This will be called via MethodChannel from Flutter OR
     * by an Intent from SmsReceiver.
     */
    fun incrementCounter(): Int {
        counter++
        Log.d(TAG, "Counter incremented to: $counter")
        updateNotification() // Update the notification with the new counter value
        return counter
    }

    /**
     * Public method to get the current counter value. This will be called via MethodChannel from
     * Flutter.
     */
    fun getCounter(): Int {
        Log.d(TAG, "Current counter value requested: $counter")
        return counter
    }

    // --- Notification Helper Methods ---

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel =
                    NotificationChannel(
                            CHANNEL_ID,
                            "Counter Service Channel",
                            NotificationManager.IMPORTANCE_LOW // Importance LOW for less intrusive
                            // notification
                            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun updateNotification() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent =
                PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE)

        val notification =
                NotificationCompat.Builder(this, CHANNEL_ID)
                        .setContentTitle("Counter Service Running")
                        .setContentText("Current Count: $counter")
                        .setSmallIcon(R.drawable.ic_stat_name) // Use a proper icon for your app
                        .setContentIntent(pendingIntent)
                        .setPriority(NotificationCompat.PRIORITY_LOW)
                        .build()

        val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun sendToApi(smsSender: String?, smsBody: String?) {
        if (smsSender == null || smsBody == null) {
            Log.w(TAG, "SMS sender or body is null, skipping API call")
            return
        }

        val (url, apiKey, phoneNumbers) = getStoredSettings()
        if (url.isNullOrEmpty() || apiKey.isNullOrEmpty()) {
            Log.w(TAG, "API URL or API Key not configured, skipping API call")
            return
        }

        // Check if phone numbers are configured and if sender matches any of them
        if (phoneNumbers.isNotEmpty()) {
            val senderMatches = phoneNumbers.any { configuredNumber ->
                // Check for exact match or if the sender contains the configured number
                smsSender == configuredNumber || 
                smsSender.contains(configuredNumber) ||
                configuredNumber.contains(smsSender)
            }
            
            if (!senderMatches) {
                Log.d(TAG, "SMS sender '$smsSender' does not match any configured phone numbers: $phoneNumbers. Skipping API call")
                return
            }
            
            Log.d(TAG, "SMS sender '$smsSender' matches configured phone numbers. Proceeding with API call")
        } else {
            Log.d(TAG, "No phone numbers configured, sending all SMS to API")
            return
        }

        Log.d(TAG, "Sending SMS to API: sender=$smsSender, body=$smsBody")

        // Use Kotlin's built-in HttpURLConnection for a simple HTTP POST
        Thread {
                    try {
                        val apiUrl = java.net.URL(url)
                        val connection = apiUrl.openConnection() as java.net.HttpURLConnection
                        connection.requestMethod = "POST"
                        connection.setRequestProperty("Content-Type", "application/json")
                        connection.setRequestProperty("Authorization", "Bearer $apiKey")
                        connection.doOutput = true

                        val jsonBody = JSONObject()
                        jsonBody.put("sender", smsSender)
                        jsonBody.put("body", smsBody)

                        val outputStream = connection.outputStream
                        outputStream.write(jsonBody.toString().toByteArray(Charsets.UTF_8))
                        outputStream.flush()
                        outputStream.close()

                        val responseCode = connection.responseCode
                        Log.d(TAG, "API Response Code: $responseCode")
                        connection.inputStream.close()
                        connection.disconnect()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error sending SMS to API: ${e.message}")
                    }
                }
                .start()
    }

    private fun getStoredSettings(): Triple<String?, String?, List<String>> {
        val sharedPrefs: SharedPreferences =
                getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val settingsJson = sharedPrefs.getString("flutter.settings_data", null)

        return if (settingsJson != null) {
            try {
                val jsonObject = JSONObject(settingsJson)
                val url = if (jsonObject.optString("url", "").isNotEmpty()) jsonObject.optString("url", "") else null
                val apiKey = if (jsonObject.optString("apiKey", "").isNotEmpty()) jsonObject.optString("apiKey", "") else null
                val phoneNumbers = mutableListOf<String>()
                
                // Parse phone numbers array if it exists
                if (jsonObject.has("phoneNumbers")) {
                    val phoneNumbersArray = jsonObject.getJSONArray("phoneNumbers")
                    for (i in 0 until phoneNumbersArray.length()) {
                        phoneNumbers.add(phoneNumbersArray.getString(i))
                    }
                }
                
                Triple(url, apiKey, phoneNumbers)
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing settings JSON: ${e.message}")
                Triple(null, null, emptyList())
            }
        } else {
            Log.d(TAG, "No settings found in SharedPreferences")
            Triple(null, null, emptyList())
        }
    }

    companion object {
        const val CHANNEL_ID = "CounterServiceChannel"
        const val NOTIFICATION_ID = 101 // Unique ID for your notification
        const val ACTION_INCREMENT_COUNTER_FROM_SMS =
                "com.example.flutter_app.INCREMENT_COUNTER_FROM_SMS"
    }
}
