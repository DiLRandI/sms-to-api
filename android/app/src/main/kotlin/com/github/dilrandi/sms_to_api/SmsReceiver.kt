package com.github.dilrandi.sms_to_api

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive called with action: ${intent.action}")
        
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            Log.d(TAG, "SMS_RECEIVED_ACTION detected - SMS received!")
            
            // Log SMS details for debugging
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages != null && messages.isNotEmpty()) {
                Log.d(TAG, "Found ${messages.size} SMS messages")
                for (message in messages) {
                    Log.d(TAG, "SMS from: ${message.originatingAddress}, body: ${message.messageBody}")
                }
            } else {
                Log.w(TAG, "No SMS messages found in intent")
            }
            
            // Start the SMS processing service
            Log.d(TAG, "Starting SmsForwardingService...")
            val serviceIntent = Intent(context, SmsForwardingService::class.java)
            serviceIntent.action = SmsForwardingService.ACTION_PROCESS_SMS
            try {
                context.startForegroundService(serviceIntent)
                Log.d(TAG, "SmsForwardingService started successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start SmsForwardingService: ${e.message}")
            }
        } else {
            Log.d(TAG, "Received intent with different action: ${intent.action}")
        }
    }
}
