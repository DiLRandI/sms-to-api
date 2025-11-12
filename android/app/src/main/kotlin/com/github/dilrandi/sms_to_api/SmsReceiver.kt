package com.github.dilrandi.sms_to_api

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Telephony
import android.telephony.SmsMessage
import androidx.core.content.ContextCompat

class SmsReceiver : BroadcastReceiver() {

    private val TAG = "SmsReceiver"

    override fun onReceive(context: Context?, intent: Intent?) {
        // Ensure the context and intent are not null and the action matches SMS_RECEIVED_ACTION
        if (context == null ||
                        intent == null ||
                        intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION
        ) {
            // Use LogManager for warnings to surface in Flutter UI
            context?.let {
                LogManager(it)
                        .logWarning(TAG, "Invalid intent or action received: ${intent?.action}")
            }
            return
        }

        PermissionMonitor.ensureMonitoring(context)

        val hasPermission =
                ContextCompat.checkSelfPermission(context, Manifest.permission.RECEIVE_SMS) ==
                        PackageManager.PERMISSION_GRANTED
        if (!hasPermission) {
            LogManager(context)
                    .logWarning(TAG, "RECEIVE_SMS permission missing; cannot process incoming messages.")
            return
        }

        // Use Telephony.Sms.Intents.getMessagesFromIntent() for modern API usage
        val messages: Array<SmsMessage>? = Telephony.Sms.Intents.getMessagesFromIntent(intent)

        if (messages.isNullOrEmpty()) {
            LogManager(context).logWarning(TAG, "No SMS messages found in the intent.")
            return
        }

        // Concatenate all SMS parts into a single message
        val messageBuilder = StringBuilder()
        var sender: String? = null
        var messageCount = 0

        for (smsMessage in messages) {
            if (sender == null) {
                sender = smsMessage.displayOriginatingAddress
            }
            messageBuilder.append(smsMessage.messageBody)
            messageCount++
        }

        val completeMessageBody = messageBuilder.toString()
        val fullMessage = "SMS from: $sender\nMessage: $completeMessageBody (Parts: $messageCount)"
        // Route debug to LogManager (non-persistent), still visible in logcat
        LogManager(context).logDebug(TAG, fullMessage)

        // Send the complete concatenated message as a single API call
        SmsForwardingWorker.enqueue(
                context.applicationContext,
                sender,
                completeMessageBody,
                messageCount,
                System.currentTimeMillis()
        )
        LogManager(context)
                .logInfo(TAG, "Enqueued SMS forwarding work for sender: $sender (parts: $messageCount)")
    }
}
