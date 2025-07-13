package com.github.dilrandi.sms_to_api


import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import android.widget.Toast
import android.os.Build

class SmsReceiver : BroadcastReceiver() {

    private val TAG = "SmsReceiver"

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val bundle = intent.extras
            if (bundle != null) {
                val pdus = bundle.get("pdus") as Array<*>?
                pdus?.let {
                    for (i in it.indices) {
                        val smsMessage = SmsMessage.createFromPdu(it[i] as ByteArray)
                        val sender = smsMessage.displayOriginatingAddress
                        val messageBody = smsMessage.messageBody

                        val fullMessage = "SMS from: $sender\nMessage: $messageBody"
                        Log.d(TAG, fullMessage)

                        // For demonstration, show a toast. In a real app, avoid toasts from BroadcastReceivers.
                        Toast.makeText(context, "SMS received! $fullMessage", Toast.LENGTH_LONG).show()

                        // --- IMPORTANT: Send Intent to CounterService to increment counter ---
                        context?.let { ctx ->
                            val serviceIntent = Intent(ctx, CounterService::class.java).apply {
                                action = CounterService.ACTION_INCREMENT_COUNTER_FROM_SMS
                                putExtra("sms_sender", sender)
                                putExtra("sms_body", messageBody)
                            }

                            // Start the service with the intent.
                            // If the service is already running (as a foreground service),
                            // onStartCommand will be called with this new intent.
                            // If it's not running, it will be started.
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                ctx.startForegroundService(serviceIntent)
                            } else {
                                ctx.startService(serviceIntent)
                            }
                            Log.d(TAG, "Sent intent to CounterService to increment counter.")
                        }
                    }
                }
            }
        }
    }
}