package com.flutterwallpaperplus.models

/**
 * Status payload returned to Dart for Wallpaper Auto Change.
 */
data class WallpaperAutoChangeStatusPayload(
    val isRunning: Boolean,
    val intervalMinutes: Int,
    val nextIndex: Int,
    val totalCount: Int,
    val nextRunEpochMs: Long,
    val target: String,
    val lastError: String?,
) {
    fun toMap(): HashMap<String, Any?> = hashMapOf(
        "isRunning" to isRunning,
        "intervalMinutes" to intervalMinutes,
        "nextIndex" to nextIndex,
        "totalCount" to totalCount,
        "nextRunEpochMs" to nextRunEpochMs,
        "target" to target,
        "lastError" to lastError,
    )

    companion object {
        fun stopped(
            target: String = "home",
            lastError: String? = null
        ): WallpaperAutoChangeStatusPayload = WallpaperAutoChangeStatusPayload(
            isRunning = false,
            intervalMinutes = 0,
            nextIndex = 0,
            totalCount = 0,
            nextRunEpochMs = 0L,
            target = target,
            lastError = lastError,
        )
    }
}
