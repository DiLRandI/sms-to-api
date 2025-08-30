package com.github.dilrandi.sms_to_api

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage

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
        val serviceIntent =
                Intent(context, SmsForwardingService::class.java).apply {
                    action = SmsForwardingService.ACTION_FORWARD_SMS_TO_API
                    putExtra("sms_sender", sender)
                    putExtra("sms_body", completeMessageBody)
                    putExtra("sms_parts_count", messageCount)
                    // Indicate the service can stop itself after handling this work
                    putExtra("auto_stop", true)
                }

        // Start the service appropriately based on Android version
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            LogManager(context)
                    .logDebug(
                            TAG,
                            "Sent intent to SmsForwardingService with complete message (${messageCount} parts)."
                    )
        } catch (e: IllegalStateException) {
            LogManager(context)
                    .logError(TAG, "Failed to start SmsForwardingService: ${e.message}", e)
        }
    }
}
