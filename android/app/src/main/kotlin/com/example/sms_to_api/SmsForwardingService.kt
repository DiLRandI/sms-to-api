package com.example.sms_to_api

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.IBinder
import android.provider.Telephony
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class SmsForwardingService : Service() {
    companion object {
        const val ACTION_START_SERVICE = "START_SERVICE"
        const val ACTION_STOP_SERVICE = "STOP_SERVICE"
        const val ACTION_PROCESS_SMS = "PROCESS_SMS"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "sms_forwarding_channel"
        private const val TAG = "SmsForwardingService"
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private lateinit var sharedPrefs: SharedPreferences

    override fun onCreate() {
        super.onCreate()
        sharedPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        createNotificationChannel()
        Log.d(TAG, "SMS Forwarding Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_SERVICE -> {
                startForegroundService()
                logToSharedPrefs("info", "SMS Forwarding Service started", "Background service is now active")
            }
            ACTION_STOP_SERVICE -> {
                stopForegroundService()
                logToSharedPrefs("info", "SMS Forwarding Service stopped", "Background service is now inactive")
            }
            ACTION_PROCESS_SMS -> {
                processPendingSms()
            }
        }
        return START_STICKY // Restart service if killed by system
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startForegroundService() {
        val notification = createNotification("SMS Forwarding Service is running")
        startForeground(NOTIFICATION_ID, notification)
        
        // Update service state in shared preferences
        updateServiceState(true)
        
        Log.d(TAG, "Foreground service started")
    }

    private fun stopForegroundService() {
        updateServiceState(false)
        stopForeground(true)
        stopSelf()
        Log.d(TAG, "Foreground service stopped")
    }

    private fun processPendingSms() {
        serviceScope.launch {
            try {
                Log.d(TAG, "Processing pending SMS messages")
                
                // Get the latest SMS messages
                val smsMessages = getLatestSmsMessages()
                
                for (sms in smsMessages) {
                    if (shouldForwardMessage(sms)) {
                        forwardSmsToApi(sms)
                        updateMessageCount()
                    }
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Error processing SMS: ${e.message}")
                logToSharedPrefs("error", "SMS processing failed", e.message ?: "Unknown error")
            }
        }
    }

    private fun getLatestSmsMessages(): List<SmsMessage> {
        val messages = mutableListOf<SmsMessage>()
        
        try {
            val cursor = contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                arrayOf(
                    Telephony.Sms._ID,
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE,
                    Telephony.Sms.TYPE
                ),
                "${Telephony.Sms.TYPE} = ? AND ${Telephony.Sms.DATE} > ?",
                arrayOf(
                    Telephony.Sms.MESSAGE_TYPE_INBOX.toString(),
                    getLastProcessedTimestamp().toString()
                ),
                "${Telephony.Sms.DATE} DESC LIMIT 10"
            )

            cursor?.use {
                while (it.moveToNext()) {
                    val id = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms._ID))
                    val address = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""
                    val body = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: ""
                    val date = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE))
                    
                    messages.add(SmsMessage(id, address, body, date))
                }
            }
            
            // Update last processed timestamp
            updateLastProcessedTimestamp(System.currentTimeMillis())
            
        } catch (e: Exception) {
            Log.e(TAG, "Error reading SMS messages: ${e.message}")
        }
        
        return messages
    }

    private fun shouldForwardMessage(sms: SmsMessage): Boolean {
        // Check if contact filtering is enabled
        val filterMode = sharedPrefs.getString("flutter.contact_filter_mode", "disabled") ?: "disabled"
        
        if (filterMode == "disabled") {
            return true
        }
        
        val contactsJson = sharedPrefs.getString("flutter.filtered_contacts", "[]") ?: "[]"
        val filteredContacts = parseContactsFromJson(contactsJson)
        
        val normalizedSender = normalizePhoneNumber(sms.address)
        val isInList = filteredContacts.any { normalizePhoneNumber(it) == normalizedSender }
        
        return when (filterMode) {
            "whitelist" -> isInList
            "blacklist" -> !isInList
            else -> true
        }
    }

    private fun normalizePhoneNumber(number: String): String {
        return number.replace(Regex("[^0-9+]"), "")
    }

    private fun parseContactsFromJson(json: String): List<String> {
        return try {
            val contacts = mutableListOf<String>()
            val jsonArray = org.json.JSONArray(json)
            for (i in 0 until jsonArray.length()) {
                contacts.add(jsonArray.getString(i))
            }
            contacts
        } catch (e: Exception) {
            emptyList()
        }
    }

    private suspend fun forwardSmsToApi(sms: SmsMessage) {
        try {
            val apiUrl = sharedPrefs.getString("flutter.api_url", "") ?: ""
            val apiKey = sharedPrefs.getString("flutter.api_key", "") ?: ""
            
            if (apiUrl.isEmpty()) {
                Log.w(TAG, "API URL not configured, skipping SMS forward")
                return
            }
            
            val jsonPayload = JSONObject().apply {
                put("from", sms.address)
                put("message", sms.body)
                put("timestamp", sms.date)
                put("id", sms.id)
            }
            
            val url = URL(apiUrl)
            val connection = url.openConnection() as HttpURLConnection
            connection.apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                if (apiKey.isNotEmpty()) {
                    setRequestProperty("Authorization", "Bearer $apiKey")
                }
                doOutput = true
            }
            
            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(jsonPayload.toString())
                writer.flush()
            }
            
            val responseCode = connection.responseCode
            if (responseCode in 200..299) {
                Log.d(TAG, "SMS forwarded successfully: ${sms.address}")
                logToSharedPrefs("success", "SMS forwarded", "From: ${sms.address}")
            } else {
                Log.w(TAG, "API returned error code: $responseCode")
                logToSharedPrefs("warning", "API error", "Response code: $responseCode")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error forwarding SMS: ${e.message}")
            logToSharedPrefs("error", "SMS forward failed", e.message ?: "Unknown error")
        }
    }

    private fun updateMessageCount() {
        val currentCount = sharedPrefs.getInt("flutter.message_count", 0)
        sharedPrefs.edit().putInt("flutter.message_count", currentCount + 1).apply()
    }

    private fun getLastProcessedTimestamp(): Long {
        return sharedPrefs.getLong("flutter.last_processed_timestamp", System.currentTimeMillis() - 60000)
    }

    private fun updateLastProcessedTimestamp(timestamp: Long) {
        sharedPrefs.edit().putLong("flutter.last_processed_timestamp", timestamp).apply()
    }

    private fun updateServiceState(isActive: Boolean) {
        sharedPrefs.edit().putBoolean("flutter.service_enabled", isActive).apply()
    }

    private fun logToSharedPrefs(level: String, message: String, details: String) {
        try {
            val currentLogs = sharedPrefs.getString("flutter.app_logs", "[]") ?: "[]"
            val logsArray = org.json.JSONArray(currentLogs)
            
            val logEntry = JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("level", level)
                put("message", message)
                put("details", details)
                put("timestamp", System.currentTimeMillis())
            }
            
            logsArray.put(logEntry)
            
            // Keep only last 100 logs to prevent memory issues
            val trimmedArray = org.json.JSONArray()
            val startIndex = maxOf(0, logsArray.length() - 100)
            for (i in startIndex until logsArray.length()) {
                trimmedArray.put(logsArray.get(i))
            }
            
            sharedPrefs.edit().putString("flutter.app_logs", trimmedArray.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error logging to shared prefs: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SMS Forwarding Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background service for forwarding SMS messages"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(content: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SMS to API")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        Log.d(TAG, "SMS Forwarding Service destroyed")
    }
}

data class SmsMessage(
    val id: Long,
    val address: String,
    val body: String,
    val date: Long
)
