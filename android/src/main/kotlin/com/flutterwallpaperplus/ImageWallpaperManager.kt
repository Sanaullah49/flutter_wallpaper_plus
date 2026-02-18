package com.flutterwallpaperplus

import android.app.WallpaperManager
import android.content.Context
import android.graphics.Rect
import android.os.Build
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import com.flutterwallpaperplus.models.ResultPayload
import com.flutterwallpaperplus.models.WallpaperConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileInputStream

/**
 * Handles setting static image wallpapers using Android's WallpaperManager.
 *
 * Design decisions:
 *
 * 1. Uses setStream() instead of setBitmap() — this is critical for memory
 *    efficiency. setBitmap() loads the entire image into a Bitmap object in
 *    memory (can be 20-50 MB for a 4K photo). setStream() lets the system
 *    decode the image incrementally.
 *
 * 2. Checks isWallpaperSupported and isSetWallpaperAllowed before attempting
 *    the operation. Some managed/kiosk devices block wallpaper changes.
 *
 * 3. Handles the FLAG_SYSTEM / FLAG_LOCK / both flags properly across API
 *    levels. The flags parameter in setStream() requires API 24+, which
 *    is our minSdk, so we always have flag support.
 *
 * 4. Catches SecurityException separately from generic exceptions because
 *    it indicates a permission problem (actionable by the user) rather than
 *    a system error.
 *
 * 5. Uses visibleCropHint=null and allowBackup=true to let the system
 *    handle cropping and parallax automatically.
 */
class ImageWallpaperManager(private val context: Context) {

    companion object {
        private const val TAG = "ImageWallpaperManager"
    }

    /**
     * Sets an image file as wallpaper on the specified target screen(s).
     *
     * This method runs entirely on Dispatchers.IO and never blocks
     * the main thread.
     *
     * @param imageFile The local image file to set as wallpaper.
     *   Must exist, be readable, and be non-empty.
     * @param config The wallpaper configuration including target,
     *   messages, and toast preferences.
     * @return A [ResultPayload] indicating success or failure with
     *   a specific error code.
     */
    suspend fun setWallpaper(
        imageFile: File,
        config: WallpaperConfig
    ): ResultPayload = withContext(Dispatchers.IO) {
        try {
            // --- Pre-flight checks ---

            val wallpaperManager = WallpaperManager.getInstance(context)

            // Check 1: Is wallpaper supported on this device?
            if (!wallpaperManager.isWallpaperSupported) {
                Log.w(TAG, "Wallpaper not supported on this device")
                return@withContext ResultPayload.error(
                    "Wallpaper is not supported on this device",
                    "unsupported"
                )
            }

            // Check 2: Is setting wallpaper allowed by device policy?
            // Available on API 24+ (our minSdk)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                if (!wallpaperManager.isSetWallpaperAllowed) {
                    Log.w(TAG, "Setting wallpaper is blocked by device policy")
                    return@withContext ResultPayload.error(
                        "Setting wallpaper is blocked by device policy. "
                                + "This may be due to MDM, parental controls, "
                                + "or manufacturer restrictions.",
                        "manufacturerRestriction"
                    )
                }
            }

            // Check 3: Validate the file
            val fileValidation = validateFile(imageFile)
            if (fileValidation != null) {
                return@withContext fileValidation
            }

            // --- Determine wallpaper flags ---
            Log.d(
                TAG,
                "Setting wallpaper: file=${imageFile.name}, "
                        + "size=${imageFile.length()}, "
                        + "target=${config.target}"
            )

            // --- Apply wallpaper ---
            val applyResult = when (config.target) {
                "both" -> setBothWithFallback(wallpaperManager, imageFile)
                else -> {
                    val flags = resolveFlags(config.target)
                    setWallpaperForFlags(wallpaperManager, imageFile, flags)
                    null
                }
            }

            if (applyResult != null) {
                return@withContext applyResult
            }

            Log.d(TAG, "Wallpaper set successfully")

            ResultPayload.success(config.successMessage)

        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException setting wallpaper", e)
            ResultPayload.error(
                "Permission denied: ${e.message ?: "SET_WALLPAPER permission required"}",
                "permissionDenied"
            )
        } catch (e: java.io.IOException) {
            Log.e(TAG, "IOException setting wallpaper", e)
            ResultPayload.error(
                "IO error while setting wallpaper: ${e.message ?: "Unknown IO error"}",
                "applyFailed"
            )
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "OutOfMemoryError setting wallpaper", e)
            ResultPayload.error(
                "Image is too large to process. Try a smaller image.",
                "applyFailed"
            )
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "IllegalArgumentException setting wallpaper", e)
            ResultPayload.error(
                "Invalid image format or corrupted file: ${e.message}",
                "applyFailed"
            )
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error setting wallpaper", e)
            ResultPayload.error(
                "Failed to set wallpaper: ${e.message ?: "Unknown error"}",
                "applyFailed"
            )
        }
    }

    private fun setBothWithFallback(
        wallpaperManager: WallpaperManager,
        imageFile: File
    ): ResultPayload? {
        val beforeSystemId = safeGetWallpaperId(
            wallpaperManager,
            WallpaperManager.FLAG_SYSTEM
        )
        val beforeLockId = safeGetWallpaperId(
            wallpaperManager,
            WallpaperManager.FLAG_LOCK
        )
        val hadDedicatedLock = beforeSystemId > 0 &&
                beforeLockId > 0 &&
                beforeSystemId != beforeLockId
        val manufacturer = OemPolicy.manufacturerNormalized()
        val needsOemFallbackChecks = OemPolicy.isRestrictiveOem()

        Log.d(
            TAG,
            "Applying both wallpapers (combined flags first). "
                    + "beforeSystemId=$beforeSystemId, "
                    + "beforeLockId=$beforeLockId, "
                    + "hadDedicatedLock=$hadDedicatedLock, "
                    + "manufacturer=$manufacturer"
        )

        // Strategy 1: Standard Android path.
        setWallpaperForFlags(
            wallpaperManager,
            imageFile,
            WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
        )

        if (!needsOemFallbackChecks) {
            // Non-targeted OEMs stay on the standard path.
            return null
        }

        // Strategy 2: Known OEMs may ignore combined flags for lock updates.
        // Force explicit system + lock writes even if combined looked successful.
        Log.w(
            TAG,
            "Running OEM fallback: explicit system+lock writes"
        )
        setWallpaperForFlags(wallpaperManager, imageFile, WallpaperManager.FLAG_SYSTEM)
        setWallpaperForFlags(wallpaperManager, imageFile, WallpaperManager.FLAG_LOCK)

        if (!hadDedicatedLock) {
            // Lock was shared (or IDs unavailable); no reliable verification possible.
            return null
        }

        val lockChangedAfterFallback = didWallpaperIdChange(
            wallpaperManager,
            WallpaperManager.FLAG_LOCK,
            beforeLockId
        )
        if (lockChangedAfterFallback) {
            return null
        }

        val systemChangedAfterFallback = didWallpaperIdChange(
            wallpaperManager,
            WallpaperManager.FLAG_SYSTEM,
            beforeSystemId
        )

        return if (!systemChangedAfterFallback) {
            // Likely the exact same wallpaper was already applied.
            null
        } else {
            ResultPayload.error(
                "Home wallpaper was updated but lock wallpaper was not. "
                        + "This device appears to block lock wallpaper updates.",
                "manufacturerRestriction"
            )
        }
    }

    private fun setWallpaperForFlags(
        wallpaperManager: WallpaperManager,
        imageFile: File,
        flags: Int
    ) {
        FileInputStream(imageFile).use { stream ->
            // setStream(InputStream, visibleCropHint, allowBackup, which)
            //
            // visibleCropHint = null → system handles cropping
            // allowBackup = true → wallpaper is included in device backups
            // which = flags → specifies home/lock/both
            wallpaperManager.setStream(
                stream,
                null,
                true,
                flags
            )
        }
    }

    private fun safeGetWallpaperId(
        wallpaperManager: WallpaperManager,
        which: Int
    ): Int {
        return try {
            wallpaperManager.getWallpaperId(which)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read wallpaper id for which=$which", e)
            -1
        }
    }

    private fun didWallpaperIdChange(
        wallpaperManager: WallpaperManager,
        which: Int,
        beforeId: Int
    ): Boolean {
        if (beforeId <= 0) {
            // Cannot verify reliably; assume success.
            return true
        }
        val afterId = safeGetWallpaperId(wallpaperManager, which)
        return afterId > 0 && afterId != beforeId
    }

    /**
     * Validates that the image file exists, is readable, and is non-empty.
     *
     * @return null if valid, or a [ResultPayload] error if invalid.
     */
    private fun validateFile(file: File): ResultPayload? {
        if (!file.exists()) {
            Log.w(TAG, "Image file does not exist: ${file.absolutePath}")
            return ResultPayload.error(
                "Image file not found: ${file.name}",
                "sourceNotFound"
            )
        }

        if (!file.isFile) {
            Log.w(TAG, "Path is not a file: ${file.absolutePath}")
            return ResultPayload.error(
                "Path is not a file: ${file.name}",
                "sourceNotFound"
            )
        }

        if (!file.canRead()) {
            Log.w(TAG, "Cannot read image file: ${file.absolutePath}")
            return ResultPayload.error(
                "Cannot read image file: ${file.name}. Check permissions.",
                "permissionDenied"
            )
        }

        if (file.length() == 0L) {
            Log.w(TAG, "Image file is empty: ${file.absolutePath}")
            return ResultPayload.error(
                "Image file is empty (0 bytes): ${file.name}",
                "sourceNotFound"
            )
        }

        return null // File is valid
    }

    /**
     * Converts a target string ("home", "lock", "both") to
     * WallpaperManager flag constants.
     *
     * API 24+ (our minSdk) always supports flags.
     *
     * Flag values:
     * - FLAG_SYSTEM = 1 (home screen)
     * - FLAG_LOCK = 2 (lock screen)
     * - FLAG_SYSTEM | FLAG_LOCK = 3 (both)
     */
    private fun resolveFlags(target: String): Int {
        return when (target) {
            "home" -> WallpaperManager.FLAG_SYSTEM
            "lock" -> WallpaperManager.FLAG_LOCK
            "both" -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
            else -> {
                Log.w(TAG, "Unknown target '$target', defaulting to both")
                WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
            }
        }
    }
}
