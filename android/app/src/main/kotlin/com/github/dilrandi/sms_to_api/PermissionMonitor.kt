package com.github.dilrandi.sms_to_api

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object PermissionMonitor {
    private const val WORK_NAME = "sms_permission_monitor"

    fun ensureMonitoring(context: Context) {
        val appContext = context.applicationContext
        val constraints = Constraints.Builder().build()
        val request =
                PeriodicWorkRequestBuilder<PermissionCheckWorker>(12, TimeUnit.HOURS)
                        .setConstraints(constraints)
                        .addTag(WORK_NAME)
                        .build()

        WorkManager.getInstance(appContext)
                .enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
    }
}
