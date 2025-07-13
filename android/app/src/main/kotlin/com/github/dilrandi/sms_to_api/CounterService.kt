package com.github.dilrandi.sms_to_api

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.util.Log

class CounterService : Service() {

    private val TAG = "CounterService"
    private var counter: Int = 0 // The counter state

    // Binder given to clients
    private val binder = CounterBinder()

    /**
     * Class used for the client Binder. Because we know this service always
     * runs in the same process as its clients, we don't need to deal with IPC.
     */
    inner class CounterBinder : Binder() {
        // Return this instance of CounterService so clients can call public methods
        fun getService(): CounterService = this@CounterService
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "CounterService: onCreate()")
    }

    override fun onBind(intent: Intent?): IBinder? {
        Log.d(TAG, "CounterService: onBind()")
        return binder
    }

    override fun onUnbind(intent: Intent?): Boolean {
        Log.d(TAG, "CounterService: onUnbind()")
        // Returning true here means onRebind() will be called if clients bind again
        return true
    }

    override fun onRebind(intent: Intent?) {
        Log.d(TAG, "CounterService: onRebind()")
        super.onRebind(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "CounterService: onDestroy()")
    }

    /**
     * Public method to increment the counter.
     * This method can be called by clients bound to the service.
     */
    fun incrementCounter(): Int {
        counter++
        Log.d(TAG, "Counter incremented to: $counter")
        return counter
    }

    /**
     * Public method to get the current counter value.
     * This method can be called by clients bound to the service.
     */
    fun getCounter(): Int {
        Log.d(TAG, "Current counter value requested: $counter")
        return counter
    }
}