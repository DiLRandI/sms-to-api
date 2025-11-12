package com.github.dilrandi.smstoapi

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import java.io.IOException
import java.security.GeneralSecurityException

object SecureSettingsBridge {
    private const val TAG = "SecureSettingsBridge"
    private const val SECURE_PREFS_NAME = "secure_sms_to_api_settings"
    private const val SECURE_KEY = "settings_data"
    private const val LEGACY_PREFS_NAME = "FlutterSharedPreferences"
    private const val LEGACY_KEY = "flutter.settings_data"

    fun write(context: Context, payload: String) {
        try {
            val encryptedPrefs = encryptedPrefs(context)
            encryptedPrefs.edit().putString(SECURE_KEY, payload).apply()
            removeLegacy(context)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write secure settings: ${e.message}")
            fallbackPrefs(context).edit().putString(LEGACY_KEY, payload).apply()
        }
    }

    fun read(context: Context): String? {
        return try {
            val encryptedPrefs = encryptedPrefs(context)
            encryptedPrefs.getString(SECURE_KEY, null) ?: migrateLegacy(context)
        } catch (e: Exception) {
            Log.w(TAG, "Falling back to legacy settings: ${e.message}")
            fallbackPrefs(context).getString(LEGACY_KEY, null)
        }
    }

    private fun migrateLegacy(context: Context): String? {
        val legacyPrefs = fallbackPrefs(context)
        val legacy = legacyPrefs.getString(LEGACY_KEY, null)
        if (legacy != null) {
            try {
                val encryptedPrefs = encryptedPrefs(context)
                encryptedPrefs.edit().putString(SECURE_KEY, legacy).apply()
                legacyPrefs.edit().remove(LEGACY_KEY).apply()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to migrate legacy settings: ${e.message}")
            }
        }
        return legacy
    }

    private fun removeLegacy(context: Context) {
        fallbackPrefs(context).edit().remove(LEGACY_KEY).apply()
    }

    private fun encryptedPrefs(context: Context): SharedPreferences {
        val masterKeyAlias = try {
            MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        } catch (e: GeneralSecurityException) {
            throw IllegalStateException("Unable to create master key", e)
        } catch (e: IOException) {
            throw IllegalStateException("Unable to access master key storage", e)
        }

        return EncryptedSharedPreferences.create(
                SECURE_PREFS_NAME,
                masterKeyAlias,
                context,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    private fun fallbackPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(LEGACY_PREFS_NAME, Context.MODE_PRIVATE)
    }
}

