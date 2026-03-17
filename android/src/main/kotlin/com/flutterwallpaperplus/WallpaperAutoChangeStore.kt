package com.flutterwallpaperplus

import android.content.Context
import com.flutterwallpaperplus.models.WallpaperAutoChangeStatusPayload
import org.json.JSONArray

/**
 * Persists Wallpaper Auto Change state across app restarts and worker runs.
 */
internal class WallpaperAutoChangeStore(context: Context) {

    companion object {
        private const val PREFS_NAME = "flutter_wallpaper_plus_auto_change"
        private const val KEY_IS_RUNNING = "is_running"
        private const val KEY_SOURCES = "sources"
        private const val KEY_TARGET = "target"
        private const val KEY_INTERVAL_MINUTES = "interval_minutes"
        private const val KEY_NEXT_INDEX = "next_index"
        private const val KEY_NEXT_RUN_EPOCH_MS = "next_run_epoch_ms"
        private const val KEY_LAST_ERROR = "last_error"
    }

    private val prefs = context.applicationContext.getSharedPreferences(
        PREFS_NAME,
        Context.MODE_PRIVATE
    )

    fun saveConfig(
        localSources: List<String>,
        target: String,
        intervalMinutes: Int
    ) {
        prefs.edit()
            .putBoolean(KEY_IS_RUNNING, true)
            .putString(KEY_SOURCES, JSONArray(localSources).toString())
            .putString(KEY_TARGET, target)
            .putInt(KEY_INTERVAL_MINUTES, intervalMinutes)
            .putInt(KEY_NEXT_INDEX, 0)
            .putLong(KEY_NEXT_RUN_EPOCH_MS, 0L)
            .putString(KEY_LAST_ERROR, null)
            .apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    fun isRunning(): Boolean = prefs.getBoolean(KEY_IS_RUNNING, false)

    fun getTarget(): String = prefs.getString(KEY_TARGET, "home") ?: "home"

    fun getIntervalMinutes(): Int = prefs.getInt(KEY_INTERVAL_MINUTES, 0)

    fun getNextIndex(): Int = prefs.getInt(KEY_NEXT_INDEX, 0)

    fun setNextIndex(index: Int) {
        prefs.edit().putInt(KEY_NEXT_INDEX, index).apply()
    }

    fun setNextRunEpochMs(epochMs: Long) {
        prefs.edit().putLong(KEY_NEXT_RUN_EPOCH_MS, epochMs).apply()
    }

    fun getNextRunEpochMs(): Long = prefs.getLong(KEY_NEXT_RUN_EPOCH_MS, 0L)

    fun setLastError(error: String?) {
        prefs.edit().putString(KEY_LAST_ERROR, error).apply()
    }

    fun getLastError(): String? = prefs.getString(KEY_LAST_ERROR, null)

    fun getSources(): List<String> {
        val raw = prefs.getString(KEY_SOURCES, null) ?: return emptyList()
        val jsonArray = JSONArray(raw)
        val output = ArrayList<String>(jsonArray.length())
        for (i in 0 until jsonArray.length()) {
            output.add(jsonArray.optString(i))
        }
        return output.filter { it.isNotBlank() }
    }

    fun getStatusPayload(): WallpaperAutoChangeStatusPayload {
        val sources = getSources()
        return WallpaperAutoChangeStatusPayload(
            isRunning = isRunning(),
            intervalMinutes = getIntervalMinutes(),
            nextIndex = getNextIndex(),
            totalCount = sources.size,
            nextRunEpochMs = getNextRunEpochMs(),
            target = getTarget(),
            lastError = getLastError(),
        )
    }
}
