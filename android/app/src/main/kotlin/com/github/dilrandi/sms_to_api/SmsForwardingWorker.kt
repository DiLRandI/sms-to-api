package com.github.dilrandi.sms_to_api

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters

class SmsForwardingWorker(
        appContext: Context,
        workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    private val logManager = LogManager(appContext)
    private val task = SmsForwardingTask(appContext)

    override suspend fun doWork(): Result {
        val smsSender = inputData.getString(KEY_SENDER)
        val smsBody = inputData.getString(KEY_BODY)
        val smsPartsCount = inputData.getInt(KEY_PARTS_COUNT, 1)

        val plan = task.planWork(smsSender, smsBody, smsPartsCount)
        if (plan == null) {
            logManager.logDebug(TAG, "No forwarding plan generated for work $id; skipping")
            return Result.success()
        }

        return try {
            task.execute(plan)
            Result.success()
        } catch (e: Exception) {
            logManager.logError(TAG, "Error forwarding SMS via worker: ${e.message}", e)
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "SmsForwardingWorker"
        const val KEY_SENDER = "sms_sender"
        const val KEY_BODY = "sms_body"
        const val KEY_PARTS_COUNT = "sms_parts_count"
        const val KEY_RECEIVED_AT = "sms_received_at"

        fun enqueue(
                context: Context,
                sender: String?,
                body: String?,
                partsCount: Int,
                receivedAt: Long
        ) {
            val data = Data.Builder()
                    .putString(KEY_SENDER, sender)
                    .putString(KEY_BODY, body)
                    .putInt(KEY_PARTS_COUNT, partsCount)
                    .putLong(KEY_RECEIVED_AT, receivedAt)
                    .build()

            val constraints = Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()

            val request =
                    OneTimeWorkRequestBuilder<SmsForwardingWorker>()
                            .setInputData(data)
                            .setConstraints(constraints)
                            .addTag(TAG)
                            .build()

            val workName = "sms_forward_${receivedAt}_${sender ?: "unknown"}"
            WorkManager.getInstance(context)
                    .enqueueUniqueWork(workName, ExistingWorkPolicy.REPLACE, request)
        }
    }
}
