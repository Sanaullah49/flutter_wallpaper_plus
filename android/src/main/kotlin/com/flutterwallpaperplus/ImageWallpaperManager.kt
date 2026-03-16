package com.flutterwallpaperplus

import android.app.WallpaperManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
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
 * 1. Uses setStream() as the primary apply path for memory efficiency, while
 *    keeping a bitmap fallback for lock-sensitive targets on OEMs where the
 *    simpler legacy bitmap flow has proven more reliable in production.
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
 *    handle cropping and parallax automatically, regardless of whether
 *    the apply path uses streams or a decoded bitmap fallback.
 */
class ImageWallpaperManager(private val context: Context) {

    companion object {
        private const val TAG = "ImageWallpaperManager"
    }

    private val imageNormalizer: ImageNormalizer by lazy {
        ImageNormalizer(context)
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

            val preparedFile = imageNormalizer.normalizeIfNeeded(
                imageFile = imageFile,
                target = config.target,
            )

            val preparedFileValidation = validateFile(preparedFile)
            if (preparedFileValidation != null) {
                return@withContext preparedFileValidation
            }

            // --- Determine wallpaper flags ---
            Log.d(
                TAG,
                "Setting wallpaper: file=${preparedFile.name}, "
                        + "size=${preparedFile.length()}, "
                        + "target=${config.target}"
            )

            // --- Apply wallpaper ---
            val applyResult = when (config.target) {
                "home" -> {
                    setWallpaperForFlags(
                        wallpaperManager = wallpaperManager,
                        imageFile = preparedFile,
                        flags = WallpaperManager.FLAG_SYSTEM
                    )
                    null
                }

                "lock" -> setLockWithCompatibilityFallback(
                    wallpaperManager = wallpaperManager,
                    imageFile = preparedFile
                )

                "both" -> setBothWithCompatibilityFallback(
                    wallpaperManager = wallpaperManager,
                    imageFile = preparedFile
                )

                else -> {
                    val flags = resolveFlags(config.target)
                    setWallpaperForFlags(wallpaperManager, preparedFile, flags)
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

    private fun setLockWithCompatibilityFallback(
        wallpaperManager: WallpaperManager,
        imageFile: File
    ): ResultPayload? {
        val restrictiveOem = OemPolicy.isRestrictiveOem()
        val beforeLockId = safeGetWallpaperId(
            wallpaperManager,
            WallpaperManager.FLAG_LOCK
        )

        Log.d(
            TAG,
            "Applying lock wallpaper. "
                    + "beforeLockId=$beforeLockId, "
                    + "restrictiveOem=$restrictiveOem"
        )

        setWallpaperForFlags(
            wallpaperManager = wallpaperManager,
            imageFile = imageFile,
            flags = WallpaperManager.FLAG_LOCK
        )

        val lockChanged = didWallpaperIdChange(
            wallpaperManager = wallpaperManager,
            which = WallpaperManager.FLAG_LOCK,
            beforeId = beforeLockId
        )

        if (restrictiveOem || !lockChanged) {
            Log.d(
                TAG,
                "Retrying lock wallpaper with bitmap fallback. "
                        + "restrictiveOem=$restrictiveOem, "
                        + "lockChanged=$lockChanged"
            )
            withDecodedBitmap(imageFile) { bitmap ->
                setWallpaperForFlagsBitmap(
                    wallpaperManager = wallpaperManager,
                    bitmap = bitmap,
                    flags = WallpaperManager.FLAG_LOCK
                )
            }
        }

        return null
    }

    private fun setBothWithCompatibilityFallback(
        wallpaperManager: WallpaperManager,
        imageFile: File
    ): ResultPayload? {
        val restrictiveOem = OemPolicy.isRestrictiveOem()
        val beforeSystemId = safeGetWallpaperId(
            wallpaperManager,
            WallpaperManager.FLAG_SYSTEM
        )
        val beforeLockId = safeGetWallpaperId(
            wallpaperManager,
            WallpaperManager.FLAG_LOCK
        )

        Log.d(
            TAG,
            "Applying both wallpapers sequentially. "
                    + "beforeSystemId=$beforeSystemId, "
                    + "beforeLockId=$beforeLockId, "
                    + "restrictiveOem=$restrictiveOem"
        )

        Log.d(TAG, "Setting home screen wallpaper...")
        setWallpaperForFlags(
            wallpaperManager = wallpaperManager,
            imageFile = imageFile,
            flags = WallpaperManager.FLAG_SYSTEM
        )

        val systemChanged = didWallpaperIdChange(
            wallpaperManager = wallpaperManager,
            which = WallpaperManager.FLAG_SYSTEM,
            beforeId = beforeSystemId
        )

        if (restrictiveOem || !systemChanged) {
            Log.d(
                TAG,
                "Retrying home wallpaper with bitmap fallback. "
                        + "restrictiveOem=$restrictiveOem, "
                        + "systemChanged=$systemChanged"
            )
            withDecodedBitmap(imageFile) { bitmap ->
                setWallpaperForFlagsBitmap(
                    wallpaperManager = wallpaperManager,
                    bitmap = bitmap,
                    flags = WallpaperManager.FLAG_SYSTEM
                )
            }
        }

        sleepBetweenSequentialWrites()

        Log.d(TAG, "Setting lock screen wallpaper...")
        setWallpaperForFlags(
            wallpaperManager = wallpaperManager,
            imageFile = imageFile,
            flags = WallpaperManager.FLAG_LOCK
        )

        val lockChanged = didWallpaperIdChange(
            wallpaperManager = wallpaperManager,
            which = WallpaperManager.FLAG_LOCK,
            beforeId = beforeLockId
        )

        if (restrictiveOem || !lockChanged) {
            Log.d(
                TAG,
                "Retrying lock wallpaper with bitmap fallback. "
                        + "restrictiveOem=$restrictiveOem, "
                        + "lockChanged=$lockChanged"
            )
            withDecodedBitmap(imageFile) { bitmap ->
                setWallpaperForFlagsBitmap(
                    wallpaperManager = wallpaperManager,
                    bitmap = bitmap,
                    flags = WallpaperManager.FLAG_LOCK
                )
            }
        }

        Log.d(TAG, "Both wallpapers set sequentially - success")
        return null
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

    private fun setWallpaperForFlagsBitmap(
        wallpaperManager: WallpaperManager,
        bitmap: Bitmap,
        flags: Int
    ) {
        wallpaperManager.setBitmap(
            bitmap,
            null,
            true,
            flags
        )
    }

    private inline fun withDecodedBitmap(
        imageFile: File,
        block: (Bitmap) -> Unit
    ) {
        val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
            ?: throw IllegalArgumentException(
                "Failed to decode prepared wallpaper bitmap: ${imageFile.name}"
            )
        try {
            block(bitmap)
        } finally {
            if (!bitmap.isRecycled) {
                bitmap.recycle()
            }
        }
    }

    private fun sleepBetweenSequentialWrites() {
        try {
            Thread.sleep(500)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            Log.w(TAG, "Delay interrupted", e)
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
