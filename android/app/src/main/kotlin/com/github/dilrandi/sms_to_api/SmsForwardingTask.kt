package com.github.dilrandi.sms_to_api

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

data class Endpoint(
        val id: String,
        val name: String,
        val url: String,
        val apiKey: String,
        val active: Boolean,
        val authHeaderName: String = "Authorization"
)

data class AppSettings(
        val authHeaderName: String,
        val phoneNumbers: List<String>,
        val endpoints: List<Endpoint>
)

data class ForwardingPlan(
        val sender: String,
        val body: String,
        val partsCount: Int,
        val authHeaderName: String,
        val endpoints: List<Endpoint>
)

class SmsForwardingTask(private val context: Context) {

    private val logManager = LogManager(context)

    fun planWork(smsSender: String?, smsBody: String?, smsPartsCount: Int): ForwardingPlan? {
        if (smsSender.isNullOrBlank() || smsBody.isNullOrBlank()) {
            logManager.logWarning(TAG, "SMS sender or body is null, skipping API call")
            return null
        }

        val settings = getStoredSettings()
        val activeEndpoints = settings.endpoints.filter { it.active }
        if (activeEndpoints.isEmpty()) {
            logManager.logWarning(TAG, "No active API endpoints configured, skipping API call")
            return null
        }

        if (settings.phoneNumbers.isNotEmpty()) {
            val senderMatches =
                    settings.phoneNumbers.any { configuredNumber ->
                        smsSender == configuredNumber ||
                                smsSender.contains(configuredNumber) ||
                                configuredNumber.contains(smsSender)
                    }

            if (!senderMatches) {
                logManager.logDebug(
                        TAG,
                        "SMS sender '$smsSender' does not match any configured phone numbers: ${settings.phoneNumbers}. Skipping API call"
                )
                return null
            }

            logManager.logInfo(
                    TAG,
                    "SMS sender '$smsSender' matches configured phone numbers. Proceeding with API call"
            )
        } else {
            logManager.logInfo(TAG, "No phone numbers configured, sending all SMS to API")
        }

        val safeBody = smsBody.take(160).let { if (smsBody.length > 160) "$it…" else it }
        val messageInfo = if (smsPartsCount > 1) "multi-part SMS ($smsPartsCount parts)" else "SMS"
        logManager.logInfo(
                TAG,
                "Prepared $messageInfo for ${activeEndpoints.size} API endpoint(s): sender=$smsSender, body=$safeBody"
        )

        return ForwardingPlan(smsSender, smsBody, smsPartsCount, settings.authHeaderName, activeEndpoints)
    }

    suspend fun execute(plan: ForwardingPlan) {
        val messageInfo = if (plan.partsCount > 1) "multi-part SMS (${plan.partsCount} parts)" else "SMS"
        val safeBody = plan.body.take(160).let { if (plan.body.length > 160) "$it…" else it }
        logManager.logInfo(
                TAG,
                "Sending $messageInfo to ${plan.endpoints.size} API endpoint(s): sender=${plan.sender}, body=$safeBody"
        )

        withContext(Dispatchers.IO) {
            for (endpoint in plan.endpoints) {
                sendToEndpoint(endpoint, plan)
            }
        }
    }

    private fun sendToEndpoint(endpoint: Endpoint, plan: ForwardingPlan) {
        try {
            val apiUrl = java.net.URL(endpoint.url)
            val connection = apiUrl.openConnection() as java.net.HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            val headerName = endpoint.authHeaderName.ifBlank { plan.authHeaderName }
            connection.setRequestProperty(headerName, endpoint.apiKey)
            connection.doOutput = true
            connection.connectTimeout = 10000
            connection.readTimeout = 10000

            val jsonBody = JSONObject().apply {
                put("sender", plan.sender)
                put("body", plan.body)
                put("parts_count", plan.partsCount)
                put("is_multipart", plan.partsCount > 1)
                put("endpoint_name", endpoint.name)
            }

            connection.outputStream.use { outputStream ->
                outputStream.write(jsonBody.toString().toByteArray(Charsets.UTF_8))
                outputStream.flush()
            }

            val responseCode = connection.responseCode
            when {
                responseCode >= 500 ->
                        logManager.logError(TAG, "${endpoint.name}: server error ($responseCode)")
                responseCode >= 400 ->
                        logManager.logWarning(TAG, "${endpoint.name}: client error ($responseCode)")
                else ->
                        logManager.logInfo(TAG, "${endpoint.name}: request succeeded ($responseCode)")
            }

            try {
                if (responseCode >= 400) {
                    connection.errorStream?.close()
                } else {
                    connection.inputStream?.close()
                }
            } catch (_: Exception) {}
            connection.disconnect()
        } catch (e: Exception) {
            logManager.logError(TAG, "${endpoint.name}: error sending SMS: ${e.message}", e)
        }
    }

    private fun getStoredSettings(): AppSettings {
        val settingsJson = SecureSettingsBridge.read(context)
        return if (settingsJson != null) {
            try {
                val jsonObject = JSONObject(settingsJson)
                val authHeaderName = jsonObject.optString("authHeaderName", "Authorization")
                val phoneNumbers = mutableListOf<String>()

                if (jsonObject.has("phoneNumbers")) {
                    val phoneNumbersArray = jsonObject.getJSONArray("phoneNumbers")
                    for (i in 0 until phoneNumbersArray.length()) {
                        phoneNumbers.add(phoneNumbersArray.getString(i))
                    }
                }

                val endpoints = mutableListOf<Endpoint>()
                if (jsonObject.has("endpoints")) {
                    val arr = jsonObject.getJSONArray("endpoints")
                    for (i in 0 until arr.length()) {
                        val o = arr.getJSONObject(i)
                        val id = o.optString("id", i.toString())
                        val name = o.optString("name", "Endpoint ${i + 1}")
                        val epUrl = o.optString("url", "")
                        val epKey = o.optString("apiKey", "")
                        val active = o.optBoolean("active", true)
                        val header = o.optString("authHeaderName", "Authorization")
                        if (epUrl.isNotEmpty() && epKey.isNotEmpty()) {
                            endpoints.add(Endpoint(id, name, epUrl, epKey, active, header))
                        }
                    }
                }

                AppSettings(authHeaderName, phoneNumbers, endpoints)
            } catch (e: Exception) {
                logManager.logError(TAG, "Error parsing settings JSON: ${e.message}", e)
                AppSettings("Authorization", emptyList(), emptyList())
            }
        } else {
            logManager.logDebug(TAG, "No settings found in SharedPreferences")
            AppSettings("Authorization", emptyList(), emptyList())
        }
    }

    companion object {
        private const val TAG = "SmsForwardingTask"
    }
}
