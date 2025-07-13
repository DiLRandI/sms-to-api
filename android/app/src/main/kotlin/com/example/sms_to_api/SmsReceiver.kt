package com.example.sms_to_api

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
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            Log.d(TAG, "SMS received, starting background service")
            
            // Start the SMS processing service
            val serviceIntent = Intent(context, SmsForwardingService::class.java)
            serviceIntent.action = SmsForwardingService.ACTION_PROCESS_SMS
            context.startForegroundService(serviceIntent)
        }
    }
}
