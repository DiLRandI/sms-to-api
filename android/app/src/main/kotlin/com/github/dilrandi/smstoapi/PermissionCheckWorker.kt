package com.github.dilrandi.smstoapi

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters

class PermissionCheckWorker(
        appContext: Context,
        workerParams: WorkerParameters
) : Worker(appContext, workerParams) {

    private val logManager = LogManager(appContext)

    override fun doWork(): Result {
        val receiveGranted =
                ContextCompat.checkSelfPermission(
                        applicationContext,
                        Manifest.permission.RECEIVE_SMS
                ) == PackageManager.PERMISSION_GRANTED
        val readGranted =
                ContextCompat.checkSelfPermission(
                        applicationContext,
                        Manifest.permission.READ_SMS
                ) == PackageManager.PERMISSION_GRANTED

        return if (receiveGranted && readGranted) {
            logManager.logDebug(TAG, "SMS permissions verified by background monitor")
            Result.success()
        } else {
            logManager.logWarning(
                    TAG,
                    "SMS permissions missing: RECEIVE_SMS=$receiveGranted, READ_SMS=$readGranted"
            )
            showNotification(receiveGranted)
            Result.success()
        }
    }

    private fun showNotification(receiveGranted: Boolean) {
        val notificationManager =
                ContextCompat.getSystemService(applicationContext, NotificationManager::class.java)
                        ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                    NotificationChannel(
                            CHANNEL_ID,
                            "SMS Permission Alerts",
                            NotificationManager.IMPORTANCE_HIGH
                    ).apply { description = "Alerts when SMS permissions are revoked" }
            notificationManager.createNotificationChannel(channel)
        }

        val intent =
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", applicationContext.packageName, null)
                }
        val pendingIntent =
                PendingIntent.getActivity(
                        applicationContext,
                        0,
                        intent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )

        val contentText =
                if (receiveGranted) {
                    "READ_SMS permission missing. Tap to enable it so forwarding keeps working."
                } else {
                    "RECEIVE_SMS permission missing. Tap to re-enable it so forwarding keeps working."
                }

        val notification =
                NotificationCompat.Builder(applicationContext, CHANNEL_ID)
                        .setSmallIcon(android.R.drawable.stat_notify_error)
                        .setContentTitle("SMS permissions required")
                        .setContentText(contentText)
                        .setAutoCancel(true)
                        .setPriority(NotificationCompat.PRIORITY_HIGH)
                        .setContentIntent(pendingIntent)
                        .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        private const val TAG = "PermissionCheckWorker"
        private const val CHANNEL_ID = "SmsPermissionAlerts"
        private const val NOTIFICATION_ID = 5021
    }
}
