package com.github.dilrandi.sms_to_api

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class CounterService : Service() {

    private val TAG = "CounterService"
    private var counter: Int = 0 // The counter state

    // For a started service, we don't need a Binder to expose methods directly
    // in the same way as a bound service. We'll use MethodChannel for communication.
    override fun onBind(intent: Intent?): IBinder? {
        Log.d(TAG, "CounterService: onBind() - Not providing a binding interface for started service.")
        return null // Return null for a purely started service
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "CounterService: onCreate()")
        createNotificationChannel() // Create notification channel for Android O+
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "CounterService: onStartCommand()")

        // Build the notification for the foreground service
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE // Use FLAG_IMMUTABLE for security
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Counter Service Running")
            .setContentText("Current Count: $counter") // You can update this later
            // .setSmallIcon(R.drawable.ic_stat_name) // Use a proper icon for your app
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW) // Low priority to be less intrusive
            .build()

        // Start the service in the foreground
        startForeground(NOTIFICATION_ID, notification)

        // Simulate some background work if needed, otherwise it just keeps running
        // For actual long-running tasks, use a separate thread/coroutine here.
        // For this example, the service simply runs and keeps the counter.

        // Return START_STICKY to ensure the service is restarted if killed by the system
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "CounterService: onDestroy()")
        // Clean up resources if any (e.g., stop threads, release sensors)
    }

    /**
     * Public method to increment the counter.
     * This will be called via MethodChannel from Flutter.
     */
    fun incrementCounter(): Int {
        counter++
        Log.d(TAG, "Counter incremented to: $counter")
        updateNotification() // Update the notification with the new counter value
        return counter
    }

    /**
     * Public method to get the current counter value.
     * This will be called via MethodChannel from Flutter.
     */
    fun getCounter(): Int {
        Log.d(TAG, "Current counter value requested: $counter")
        return counter
    }

    // --- Notification Helper Methods ---

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Counter Service Channel",
                NotificationManager.IMPORTANCE_LOW // Importance LOW for less intrusive notification
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun updateNotification() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Counter Service Running")
            .setContentText("Current Count: $counter")
            // .setSmallIcon(R.drawable.ic_stat_name) // Use a proper icon for your app
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        const val CHANNEL_ID = "CounterServiceChannel"
        const val NOTIFICATION_ID = 101 // Unique ID for your notification
    }
}