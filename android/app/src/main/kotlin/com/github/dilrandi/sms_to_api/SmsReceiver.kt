package com.github.dilrandi.sms_to_api

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import android.widget.Toast

class SmsReceiver : BroadcastReceiver() {

    private val TAG = "SmsReceiver"

    override fun onReceive(context: Context?, intent: Intent?) {
        // Ensure the context and intent are not null and the action matches SMS_RECEIVED_ACTION
        if (context == null ||
                        intent == null ||
                        intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION
        ) {
            Log.w(TAG, "Invalid intent or action received: ${intent?.action}")
            return
        }

        // Use Telephony.Sms.Intents.getMessagesFromIntent() for modern API usage
        val messages: Array<SmsMessage>? = Telephony.Sms.Intents.getMessagesFromIntent(intent)

        if (messages.isNullOrEmpty()) {
            Log.w(TAG, "No SMS messages found in the intent.")
            return
        }

        // Process each SMS message
        for (smsMessage in messages) {
            val sender = smsMessage.displayOriginatingAddress
            val messageBody = smsMessage.messageBody

            val fullMessage = "SMS from: $sender\nMessage: $messageBody"
            Log.d(TAG, fullMessage)

            val serviceIntent =
                    Intent(context, CounterService::class.java).apply {
                        action = CounterService.ACTION_INCREMENT_COUNTER_FROM_SMS
                        putExtra("sms_sender", sender)
                        putExtra("sms_body", messageBody)
                    }

            // Start the service appropriately based on Android version
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                Log.d(TAG, "Sent intent to CounterService to increment counter.")
            } catch (e: IllegalStateException) {
                Log.e(TAG, "Failed to start CounterService: ${e.message}")
            }
        }
    }
}
