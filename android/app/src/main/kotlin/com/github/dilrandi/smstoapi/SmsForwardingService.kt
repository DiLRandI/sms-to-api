package com.github.dilrandi.smstoapi

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class SmsForwardingService : Service() {

    private val TAG = "SmsForwardingService"
    private lateinit var logManager: LogManager
    private lateinit var forwardingTask: SmsForwardingTask
    @Volatile private var boundClients: Int = 0
    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(serviceJob + Dispatchers.IO)

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
        serviceScope.launch {
            val plan =
                    forwardingTask.planWork(
                            "TEST_SENDER",
                            "This is a test message for API verification - triggered manually",
                            1
                    )
            if (plan == null) {
                logManager.logWarning(TAG, "Test API call skipped because no endpoints are configured")
                return@launch
            }
            forwardingTask.execute(plan)
        }
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
        forwardingTask = SmsForwardingTask(this)
        logManager.logInfo(TAG, "SmsForwardingService: onCreate() - Service starting up")
        logManager.logDebug(TAG, "Initializing SMS forwarding service")
        createNotificationChannel() // Create notification channel for Android O+
        logManager.logInfo(TAG, "SMS forwarding service initialization completed successfully")
        PermissionMonitor.ensureMonitoring(this)
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

            val safeBody = (smsBody ?: "").let { if (it.length > 160) it.take(160) + "…" else it }
            if (smsPartsCount > 1) {
                logManager.logInfo(
                        TAG,
                        "Received multi-part SMS ($smsPartsCount parts) from $smsSender with body: $safeBody"
                )
            } else {
                logManager.logInfo(TAG, "Received SMS from $smsSender with body: $safeBody")
            }

            val plan = forwardingTask.planWork(smsSender, smsBody, smsPartsCount)
            if (plan == null) {
                if (autoStop && boundClients == 0) {
                    logManager.logDebug(TAG, "No work plan created; stopping service early (startId=$startId)")
                    try {
                        stopSelf(startId)
                    } catch (_: Exception) {}
                }
                return START_NOT_STICKY
            }

            serviceScope.launch {
                try {
                    forwardingTask.execute(plan)
                } finally {
                    if (autoStop && boundClients == 0) {
                        withContext(Dispatchers.Main) {
                            try {
                                stopForeground(STOP_FOREGROUND_REMOVE)
                            } catch (_: Exception) {}
                            try {
                                stopSelf(startId)
                            } catch (_: Exception) {}
                        }
                    }
                }
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

        // Avoid restarting automatically; the receiver or UI can start the service when needed
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        logManager.logInfo(TAG, "SmsForwardingService: onDestroy()")
        serviceJob.cancel()
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

    companion object {
        const val CHANNEL_ID = "SmsForwardingServiceChannel"
        const val NOTIFICATION_ID = 101 // Unique ID for your notification
        const val ACTION_FORWARD_SMS_TO_API = "com.github.dilrandi.smstoapi.FORWARD_SMS_TO_API"
    }
}
