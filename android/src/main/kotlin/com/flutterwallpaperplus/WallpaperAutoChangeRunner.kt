package com.flutterwallpaperplus

import android.content.Context
import com.flutterwallpaperplus.models.ResultPayload
import com.flutterwallpaperplus.models.WallpaperConfig
import java.io.File

/**
 * Applies the next wallpaper from the current Auto Change playlist.
 */
internal class WallpaperAutoChangeRunner(context: Context) {
    private val appContext = context.applicationContext
    private val store = WallpaperAutoChangeStore(appContext)
    private val imageWallpaperManager = ImageWallpaperManager(appContext)

    companion object {
        private const val STORAGE_DIR_NAME = "wallpaper_plus_auto_change"
        fun preparedWallpapersDir(context: Context): File =
            File(context.applicationContext.filesDir, STORAGE_DIR_NAME).also {
                if (!it.exists()) {
                    it.mkdirs()
                }
            }
    }

    suspend fun applyNext(goToHome: Boolean = false): ResultPayload {
        if (!store.isRunning()) {
            return ResultPayload.error(
                "Wallpaper Auto Change is not running.",
                "unsupported"
            )
        }

        val sources = store.getSources()
        if (sources.isEmpty()) {
            store.setLastError("Wallpaper Auto Change has no prepared wallpapers.")
            return ResultPayload.error(
                "Wallpaper Auto Change has no prepared wallpapers.",
                "applyFailed"
            )
        }

        val nextIndex = positiveModulo(store.getNextIndex(), sources.size)
        val file = File(sources[nextIndex])
        if (!file.exists() || !file.canRead()) {
            val message = "Prepared auto change wallpaper is missing: ${file.name}"
            store.setLastError(message)
            return ResultPayload.error(message, "sourceNotFound")
        }

        val payload = imageWallpaperManager.setWallpaper(
            imageFile = file,
            config = WallpaperConfig(
                sourceType = "file",
                sourcePath = file.absolutePath,
                target = store.getTarget(),
                successMessage = "Wallpaper Auto Change applied",
                errorMessage = "Failed to apply next Auto Change wallpaper",
                showToast = false,
                goToHome = goToHome,
            ),
        )

        val intervalMinutes = store.getIntervalMinutes()
        if (intervalMinutes > 0) {
            store.setNextRunEpochMs(
                System.currentTimeMillis() + intervalMinutes.toLong() * 60_000L
            )
        }

        if (payload.success) {
            store.setNextIndex((nextIndex + 1) % sources.size)
            store.setLastError(null)
        } else {
            store.setLastError(payload.message)
        }

        return payload
    }

    fun clearPreparedWallpapers() {
        preparedWallpapersDir(appContext).deleteRecursively()
    }

    private fun positiveModulo(value: Int, size: Int): Int {
        if (size == 0) {
            return 0
        }
        return ((value % size) + size) % size
    }
}
