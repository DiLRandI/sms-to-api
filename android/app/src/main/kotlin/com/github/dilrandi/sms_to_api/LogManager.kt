package com.github.dilrandi.sms_to_api

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class LogManager(private val context: Context) {

    private val TAG = "LogManager"
    private val LOGS_KEY = "app_logs"
    private val MAX_LOGS = 300 // keep persistent logs bounded to a smaller size
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault())

    init {
        dateFormat.timeZone = TimeZone.getTimeZone("UTC")
    }

    private fun getSharedPreferences(): SharedPreferences {
        return context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    fun logDebug(tag: String, message: String) {
        // Debug logs go to logcat only to avoid excessive disk churn
        Log.d(tag, message)
    }

    fun logInfo(tag: String, message: String) {
        // Info logs to logcat only; persist only warnings/errors
        Log.i(tag, message)
    }

    fun logWarning(tag: String, message: String) {
        Log.w(tag, message)
        saveLogToStorage("WARNING", tag, message)
    }

    fun logError(tag: String, message: String, throwable: Throwable? = null) {
        Log.e(tag, message, throwable)
        val stackTrace = throwable?.stackTraceToString()
        saveLogToStorage("ERROR", tag, message, stackTrace)
    }

    private fun saveLogToStorage(level: String, tag: String, message: String, stackTrace: String? = null) {
        try {
            val sharedPrefs = getSharedPreferences()
            val existingLogsJson = sharedPrefs.getString("flutter.$LOGS_KEY", "[]")
            val logsArray = JSONArray(existingLogsJson)

            val logEntry = JSONObject().apply {
                put("id", generateId())
                put("timestamp", dateFormat.format(Date()))
                put("level", level)
                put("tag", tag)
                put("message", message)
                if (stackTrace != null) {
                    put("stackTrace", stackTrace)
                }
            }

            logsArray.put(logEntry)

            // Keep only the most recent logs
            val limitedLogs = JSONArray()
            val startIndex = maxOf(0, logsArray.length() - MAX_LOGS)
            for (i in startIndex until logsArray.length()) {
                limitedLogs.put(logsArray.getJSONObject(i))
            }

            sharedPrefs.edit()
                .putString("flutter.$LOGS_KEY", limitedLogs.toString())
                .apply()

        } catch (e: Exception) {
            Log.e(TAG, "Failed to save log to storage: ${e.message}")
        }
    }

    private fun generateId(): String {
        val chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return (1..8)
            .map { chars.random() }
            .joinToString("")
    }
}
