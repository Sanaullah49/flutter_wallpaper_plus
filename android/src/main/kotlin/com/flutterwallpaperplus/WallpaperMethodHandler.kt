package com.flutterwallpaperplus

import android.app.WallpaperManager
import android.content.ClipData
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.util.Log
import android.webkit.MimeTypeMap
import android.widget.Toast
import androidx.core.content.FileProvider
import com.flutterwallpaperplus.models.ResultPayload
import com.flutterwallpaperplus.models.WallpaperConfig
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.util.Locale

/**
 * Central method call handler for all plugin operations.
 *
 * All four features are now fully implemented:
 * - Phase 2: Image wallpaper
 * - Phase 3: Video wallpaper
 * - Phase 4: Thumbnail generation
 * - Phase 1: Cache management
 */
class WallpaperMethodHandler(
    private val context: Context,
    private val flutterAssets: FlutterPlugin.FlutterAssets,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "WallpaperMethodHandler"
        private const val LIVE_VIDEO_DIR_NAME = "wallpaper_plus_live"
        private const val ACTIVE_LIVE_VIDEO_BASENAME = "active_live_video"
    }

    private val scope = CoroutineScope(
        SupervisorJob() + Dispatchers.Main.immediate
    )

    private val cacheManager: CacheManager by lazy {
        CacheManager(context)
    }

    private val sourceResolver: SourceResolver by lazy {
        SourceResolver(context, cacheManager, flutterAssets)
    }

    private val imageWallpaperManager: ImageWallpaperManager by lazy {
        ImageWallpaperManager(context)
    }

    private val thumbnailGenerator: ThumbnailGenerator by lazy {
        ThumbnailGenerator(cacheManager)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "Method called: ${call.method}")

        when (call.method) {
            "setImageWallpaper" -> handleSetImageWallpaper(call, result)
            "setVideoWallpaper" -> handleSetVideoWallpaper(call, result)
            "openNativeWallpaperChooser" -> handleOpenNativeWallpaperChooser(call, result)
            "getTargetSupportPolicy" -> handleGetTargetSupportPolicy(call, result)
            "getVideoThumbnail" -> handleGetVideoThumbnail(call, result)
            "clearCache" -> handleClearCache(call, result)
            "getCacheSize" -> handleGetCacheSize(call, result)
            "setMaxCacheSize" -> handleSetMaxCacheSize(call, result)
            else -> {
                Log.w(TAG, "Unknown method: ${call.method}")
                result.notImplemented()
            }
        }
    }

    // ================================================================
    // Image Wallpaper
    // ================================================================

    @Suppress("UNCHECKED_CAST")
    private fun handleSetImageWallpaper(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        scope.launch {
            val startedAt = SystemClock.elapsedRealtime()
            var outcome = "unknown"
            try {
                val args = call.arguments as? Map<String, Any?>
                if (args == null) {
                    outcome = "invalid_args"
                    result.success(
                        ResultPayload.error(
                            "Invalid arguments passed to setImageWallpaper",
                            "applyFailed"
                        ).toMap()
                    )
                    return@launch
                }

                val config = try {
                    WallpaperConfig.fromMap(args)
                } catch (e: IllegalArgumentException) {
                    outcome = "invalid_config"
                    result.success(
                        ResultPayload.error(
                            "Invalid configuration: ${e.message}",
                            "applyFailed"
                        ).toMap()
                    )
                    return@launch
                }

                if (!config.isValid()) {
                    outcome = "invalid_source"
                    val payload = ResultPayload.error(
                        "Invalid source configuration: "
                                + "type='${config.sourceType}', "
                                + "path='${config.sourcePath}'",
                        "sourceNotFound"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                if (OemPolicy.isRestrictiveOem() &&
                    (config.target == "lock" || config.target == "both")
                ) {
                    outcome = "restricted_target"
                    val payload = ResultPayload.error(
                        "This OEM does not reliably allow third-party lock-screen "
                                + "wallpaper changes. Use home target.",
                        "manufacturerRestriction"
                    )
                    showToastIfNeeded(config.showToast, payload.message)
                    result.success(payload.toMap())
                    return@launch
                }

                if (!PermissionHelper.hasWallpaperPermission(context)) {
                    outcome = "permission_denied"
                    val payload = ResultPayload.error(
                        "SET_WALLPAPER permission is not granted.",
                        "permissionDenied"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                if (config.sourceType == "file") {
                    if (!isAppInternalPath(config.sourcePath) &&
                        !PermissionHelper.hasStorageReadPermission(context)
                    ) {
                        outcome = "permission_denied"
                        val payload = ResultPayload.error(
                            "Storage read permission is required to access "
                                    + "files outside the app directory.",
                            "permissionDenied"
                        )
                        showToastIfNeeded(config.showToast, config.errorMessage)
                        result.success(payload.toMap())
                        return@launch
                    }
                }

                val resolveStarted = SystemClock.elapsedRealtime()
                val file = try {
                    sourceResolver.resolve(config.sourceType, config.sourcePath)
                } catch (e: SourceResolver.SourceNotFoundException) {
                    outcome = "source_not_found"
                    val payload = ResultPayload.error(
                        e.message ?: "Source not found", "sourceNotFound"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                } catch (e: CacheManager.DownloadException) {
                    outcome = "download_failed"
                    val payload = ResultPayload.error(
                        e.message ?: "Download failed", "downloadFailed"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }
                Log.d(
                    TAG,
                    "setImageWallpaper source resolved in "
                            + "${SystemClock.elapsedRealtime() - resolveStarted}ms"
                )

                val applyStarted = SystemClock.elapsedRealtime()
                val payload = imageWallpaperManager.setWallpaper(file, config)
                Log.d(
                    TAG,
                    "setImageWallpaper wallpaper apply finished in "
                            + "${SystemClock.elapsedRealtime() - applyStarted}ms"
                )

                showToastIfNeeded(
                    config.showToast,
                    if (payload.success) config.successMessage
                    else config.errorMessage
                )

                if (payload.success && config.goToHome) {
                    launchHomeScreen()
                }

                outcome = if (payload.success) "success" else payload.errorCode
                result.success(payload.toMap())

            } catch (e: Exception) {
                outcome = "exception"
                Log.e(TAG, "setImageWallpaper: unexpected exception", e)
                result.success(
                    ResultPayload.error(
                        "Unexpected error: ${e.message ?: "Unknown"}", "unknown"
                    ).toMap()
                )
            } finally {
                Log.d(
                    TAG,
                    "setImageWallpaper finished: outcome=$outcome, "
                            + "total=${SystemClock.elapsedRealtime() - startedAt}ms"
                )
            }
        }
    }

    // ================================================================
    // Video Wallpaper
    // ================================================================

    @Suppress("UNCHECKED_CAST")
    private fun handleSetVideoWallpaper(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        scope.launch {
            val startedAt = SystemClock.elapsedRealtime()
            var outcome = "unknown"
            try {
                val args = call.arguments as? Map<String, Any?>
                if (args == null) {
                    outcome = "invalid_args"
                    result.success(
                        ResultPayload.error(
                            "Invalid arguments passed to setVideoWallpaper",
                            "applyFailed"
                        ).toMap()
                    )
                    return@launch
                }

                val config = try {
                    WallpaperConfig.fromMap(args)
                } catch (e: IllegalArgumentException) {
                    outcome = "invalid_config"
                    result.success(
                        ResultPayload.error(
                            "Invalid configuration: ${e.message}",
                            "applyFailed"
                        ).toMap()
                    )
                    return@launch
                }

                if (!config.isValid()) {
                    outcome = "invalid_source"
                    val payload = ResultPayload.error(
                        "Invalid source configuration: "
                                + "type='${config.sourceType}', "
                                + "path='${config.sourcePath}'",
                        "sourceNotFound"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                if (config.target == "lock") {
                    outcome = "unsupported_target"
                    val payload = ResultPayload.error(
                        "Android does not support setting live wallpaper "
                                + "on lock screen only. Use home or both.",
                        "unsupported"
                    )
                    showToastIfNeeded(config.showToast, payload.message)
                    result.success(payload.toMap())
                    return@launch
                }

                if (OemPolicy.isRestrictiveOem() && config.target == "both") {
                    outcome = "restricted_target"
                    val payload = ResultPayload.error(
                        "This OEM controls live wallpaper lock-screen behavior. "
                                + "Use home target for reliable results.",
                        "manufacturerRestriction"
                    )
                    showToastIfNeeded(config.showToast, payload.message)
                    result.success(payload.toMap())
                    return@launch
                }

                val effectiveTarget = if (config.target == "both") "home" else config.target

                Log.d(
                    TAG,
                    "setVideoWallpaper request: requestedTarget=${config.target}, "
                            + "effectiveTarget=$effectiveTarget, "
                            + "goToHome=${config.goToHome}, "
                            + "manufacturer=${Build.MANUFACTURER}, model=${Build.MODEL}"
                )

                if (!PermissionHelper.supportsLiveWallpaper(context)) {
                    outcome = "unsupported"
                    val payload = ResultPayload.error(
                        "Live wallpapers are not supported on this device.",
                        "unsupported"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                if (config.sourceType == "file") {
                    if (!isAppInternalPath(config.sourcePath) &&
                        !PermissionHelper.hasStorageReadPermission(context)
                    ) {
                        outcome = "permission_denied"
                        val payload = ResultPayload.error(
                            "Storage read permission is required to access "
                                    + "files outside the app directory.",
                            "permissionDenied"
                        )
                        showToastIfNeeded(config.showToast, config.errorMessage)
                        result.success(payload.toMap())
                        return@launch
                    }
                }

                val resolveStarted = SystemClock.elapsedRealtime()
                val file = try {
                    sourceResolver.resolve(config.sourceType, config.sourcePath)
                } catch (e: SourceResolver.SourceNotFoundException) {
                    outcome = "source_not_found"
                    val payload = ResultPayload.error(
                        e.message ?: "Source not found", "sourceNotFound"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                } catch (e: CacheManager.DownloadException) {
                    outcome = "download_failed"
                    val payload = ResultPayload.error(
                        e.message ?: "Download failed", "downloadFailed"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }
                Log.d(
                    TAG,
                    "setVideoWallpaper source resolved in "
                            + "${SystemClock.elapsedRealtime() - resolveStarted}ms"
                )

                val persistedVideoFile = try {
                    persistVideoForWallpaperService(file)
                } catch (e: Exception) {
                    outcome = "video_prepare_failed"
                    Log.e(TAG, "Failed to persist live wallpaper video", e)
                    val payload = ResultPayload.error(
                        "Failed to prepare video for live wallpaper: ${e.message}",
                        "applyFailed"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                val saved = saveVideoWallpaperConfig(persistedVideoFile, config)

                if (!saved) {
                    outcome = "prefs_save_failed"
                    val payload = ResultPayload.error(
                        "Failed to save wallpaper configuration",
                        "applyFailed"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                if (effectiveTarget == "home") {
                    // Home-only live wallpaper can still affect lock screen when
                    // lock wallpaper is not set separately. Create a dedicated
                    // lock snapshot first so home-only applies predictably.
                    prepareLockWallpaperForHomeTargetIfNeeded()
                }

                val launchResult = launchLiveWallpaperChooser(
                    goToHome = config.goToHome
                )

                if (launchResult.success) {
                    outcome = "chooser_opened"
                    showToastIfNeeded(config.showToast, config.successMessage)
                    result.success(
                        ResultPayload.success(config.successMessage).toMap()
                    )
                } else {
                    outcome = launchResult.errorCode
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(launchResult.toMap())
                }

            } catch (e: Exception) {
                outcome = "exception"
                Log.e(TAG, "setVideoWallpaper: unexpected exception", e)
                result.success(
                    ResultPayload.error(
                        "Unexpected error: ${e.message ?: "Unknown"}", "unknown"
                    ).toMap()
                )
            } finally {
                Log.d(
                    TAG,
                    "setVideoWallpaper finished: outcome=$outcome, "
                            + "total=${SystemClock.elapsedRealtime() - startedAt}ms"
                )
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleOpenNativeWallpaperChooser(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        scope.launch {
            val startedAt = SystemClock.elapsedRealtime()
            var outcome = "unknown"
            try {
                val args = call.arguments as? Map<String, Any?>
                if (args == null) {
                    outcome = "invalid_args"
                    result.success(
                        ResultPayload.error(
                            "Invalid arguments passed to openNativeWallpaperChooser",
                            "applyFailed"
                        ).toMap()
                    )
                    return@launch
                }

                val config = try {
                    WallpaperConfig.fromMap(args)
                } catch (e: IllegalArgumentException) {
                    outcome = "invalid_config"
                    result.success(
                        ResultPayload.error(
                            "Invalid configuration: ${e.message}",
                            "sourceNotFound"
                        ).toMap()
                    )
                    return@launch
                }

                if (!config.isValid()) {
                    outcome = "invalid_source"
                    result.success(
                        ResultPayload.error(
                            "Invalid source configuration: "
                                    + "type='${config.sourceType}', "
                                    + "path='${config.sourcePath}'",
                            "sourceNotFound"
                        ).toMap()
                    )
                    return@launch
                }

                if (config.sourceType == "file") {
                    if (!isAppInternalPath(config.sourcePath) &&
                        !PermissionHelper.hasStorageReadPermission(context)
                    ) {
                        outcome = "permission_denied"
                        val payload = ResultPayload.error(
                            "Storage read permission is required to access "
                                    + "files outside the app directory.",
                            "permissionDenied"
                        )
                        showToastIfNeeded(config.showToast, config.errorMessage)
                        result.success(payload.toMap())
                        return@launch
                    }
                }

                val file = try {
                    sourceResolver.resolve(config.sourceType, config.sourcePath)
                } catch (e: SourceResolver.SourceNotFoundException) {
                    outcome = "source_not_found"
                    val payload = ResultPayload.error(
                        e.message ?: "Source not found", "sourceNotFound"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                } catch (e: CacheManager.DownloadException) {
                    outcome = "download_failed"
                    val payload = ResultPayload.error(
                        e.message ?: "Download failed", "downloadFailed"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                val launchResult = if (isVideoSource(config.sourcePath, file)) {
                    if (!PermissionHelper.supportsLiveWallpaper(context)) {
                        ResultPayload.error(
                            "Live wallpapers are not supported on this device.",
                            "unsupported"
                        )
                    } else {
                        val persistedVideoFile = try {
                            persistVideoForWallpaperService(file)
                        } catch (e: Exception) {
                            outcome = "video_prepare_failed"
                            Log.e(
                                TAG,
                                "Failed to persist video for chooser flow",
                                e
                            )
                            showToastIfNeeded(config.showToast, config.errorMessage)
                            result.success(
                                ResultPayload.error(
                                    "Failed to prepare video for live wallpaper: ${e.message}",
                                    "applyFailed"
                                ).toMap()
                            )
                            return@launch
                        }

                        val saved = saveVideoWallpaperConfig(
                            persistedVideoFile,
                            config
                        )
                        if (!saved) {
                            ResultPayload.error(
                                "Failed to save wallpaper configuration",
                                "applyFailed"
                            )
                        } else {
                            launchLiveWallpaperChooser(config.goToHome)
                        }
                    }
                } else {
                    launchImageWallpaperChooser(file, config.goToHome)
                }

                if (launchResult.success) {
                    outcome = "chooser_opened"
                    showToastIfNeeded(config.showToast, config.successMessage)
                    result.success(ResultPayload.success(config.successMessage).toMap())
                } else {
                    outcome = launchResult.errorCode
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(launchResult.toMap())
                }
            } catch (e: Exception) {
                outcome = "exception"
                Log.e(TAG, "openNativeWallpaperChooser: unexpected exception", e)
                result.success(
                    ResultPayload.error(
                        "Unexpected error: ${e.message ?: "Unknown"}", "unknown"
                    ).toMap()
                )
            } finally {
                Log.d(
                    TAG,
                    "openNativeWallpaperChooser finished: outcome=$outcome, "
                            + "total=${SystemClock.elapsedRealtime() - startedAt}ms"
                )
            }
        }
    }

    private fun launchLiveWallpaperChooser(goToHome: Boolean): ResultPayload {
        if (goToHome) {
            launchHomeScreen()
        }

        try {
            val componentName = ComponentName(
                context.packageName,
                VideoWallpaperService::class.java.name
            )

            val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
                putExtra(
                    WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                    componentName
                )
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            context.startActivity(intent)
            return ResultPayload.success("Live wallpaper chooser opened")
        } catch (e: Exception) {
            Log.w(TAG, "Direct chooser failed, trying fallback", e)
        }

        try {
            val fallbackIntent = Intent(
                WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            context.startActivity(fallbackIntent)
            return ResultPayload.success(
                "Wallpaper picker opened — please select Video Wallpaper"
            )
        } catch (e: Exception) {
            Log.e(TAG, "Fallback chooser also failed", e)
        }

        return ResultPayload.error(
            "Could not open the wallpaper picker. "
                    + "This device may not support live wallpapers.",
            "unsupported"
        )
    }

    private fun launchImageWallpaperChooser(imageFile: File, goToHome: Boolean): ResultPayload {
        if (goToHome) {
            launchHomeScreen()
        }

        val imageUri = buildShareableUri(imageFile) ?: return ResultPayload.error(
            "Could not create sharable URI for the image source.",
            "applyFailed"
        )

        val attachIntent = Intent(Intent.ACTION_ATTACH_DATA).apply {
            setDataAndType(imageUri, "image/*")
            putExtra("mimeType", "image/*")
            clipData = ClipData.newUri(context.contentResolver, "wallpaper", imageUri)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            val activities = context.packageManager.queryIntentActivities(
                attachIntent,
                PackageManager.MATCH_DEFAULT_ONLY
            )
            for (info in activities) {
                context.grantUriPermission(
                    info.activityInfo.packageName,
                    imageUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }

            context.startActivity(attachIntent)
            return ResultPayload.success("Native image wallpaper chooser opened")
        } catch (e: Exception) {
            Log.w(TAG, "ACTION_ATTACH_DATA failed, trying generic chooser", e)
        }

        try {
            val chooserIntent = Intent(Intent.ACTION_SET_WALLPAPER).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(chooserIntent)
            return ResultPayload.success("Wallpaper chooser opened")
        } catch (e: Exception) {
            Log.e(TAG, "Wallpaper chooser fallback failed", e)
        }

        return ResultPayload.error(
            "Could not open the wallpaper chooser.",
            "unsupported"
        )
    }

    private fun handleGetTargetSupportPolicy(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        if (shouldGoToHome(call)) {
            launchHomeScreen()
        }
        val restrictive = OemPolicy.isRestrictiveOem()
        result.success(
            hashMapOf<String, Any>(
                "manufacturer" to OemPolicy.manufacturerRaw(),
                "model" to OemPolicy.modelRaw(),
                "restrictiveOem" to restrictive,
                "allowImageHome" to true,
                "allowImageLock" to !restrictive,
                "allowImageBoth" to !restrictive,
                "allowVideoHome" to true,
                "allowVideoLock" to false,
                "allowVideoBoth" to !restrictive,
            )
        )
    }

    private suspend fun prepareLockWallpaperForHomeTargetIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return

        withContext(Dispatchers.IO) {
            try {
                val wallpaperManager = WallpaperManager.getInstance(context)
                if (!wallpaperManager.isWallpaperSupported ||
                    !wallpaperManager.isSetWallpaperAllowed
                ) {
                    Log.d(
                        TAG,
                        "Skipping lock wallpaper prep: wallpaper changes not allowed"
                    )
                    return@withContext
                }

                val lockId = wallpaperManager.getWallpaperId(WallpaperManager.FLAG_LOCK)
                val systemId = wallpaperManager.getWallpaperId(WallpaperManager.FLAG_SYSTEM)
                val lockAlreadyDedicated = lockId > 0 && lockId != systemId

                if (lockAlreadyDedicated) {
                    Log.d(TAG, "Lock wallpaper already dedicated; no prep needed")
                    return@withContext
                }

                val snapshot = readWallpaperSnapshotBitmap(wallpaperManager)
                if (snapshot == null) {
                    Log.w(
                        TAG,
                        "Could not snapshot lock/system wallpaper before home-only live apply"
                    )
                    return@withContext
                }

                wallpaperManager.setBitmap(
                    snapshot,
                    null,
                    true,
                    WallpaperManager.FLAG_LOCK
                )
                snapshot.recycle()

                Log.d(
                    TAG,
                    "Prepared dedicated lock wallpaper for home-only live wallpaper apply"
                )
            } catch (e: SecurityException) {
                Log.w(
                    TAG,
                    "Permission denied while preparing lock wallpaper snapshot",
                    e
                )
            } catch (e: Exception) {
                Log.w(
                    TAG,
                    "Failed to prepare lock wallpaper snapshot for home target",
                    e
                )
            }
        }
    }

    private fun readWallpaperSnapshotBitmap(
        wallpaperManager: WallpaperManager
    ): Bitmap? {
        val lockOrSystemFd = try {
            wallpaperManager.getWallpaperFile(WallpaperManager.FLAG_LOCK)
                ?: wallpaperManager.getWallpaperFile(WallpaperManager.FLAG_SYSTEM)
        } catch (e: SecurityException) {
            Log.i(
                TAG,
                "Wallpaper file access denied; falling back to drawable snapshot"
            )
            null
        } catch (e: Exception) {
            Log.w(TAG, "Wallpaper file read failed; falling back to drawable snapshot", e)
            null
        }

        if (lockOrSystemFd != null) {
            ParcelFileDescriptor.AutoCloseInputStream(lockOrSystemFd).use { input ->
                val fromFile = BitmapFactory.decodeStream(input)
                if (fromFile != null) {
                    return fromFile
                }
            }
        }

        return try {
            drawableToBitmap(wallpaperManager.drawable)
        } catch (e: Exception) {
            Log.w(TAG, "Drawable snapshot fallback failed", e)
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable?): Bitmap {
        if (drawable == null) {
            throw IllegalStateException("Wallpaper drawable is null")
        }
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap.copy(Bitmap.Config.ARGB_8888, false)
        }

        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 1
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 1
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    // ================================================================
    // PHASE 4 — Thumbnail Generation (FULLY IMPLEMENTED)
    // ================================================================

    /**
     * Handles the getVideoThumbnail method call.
     *
     * Flow:
     * 1. Parse source, quality, cache flag from arguments
     * 2. Resolve source to local file
     * 3. Generate thumbnail via ThumbnailGenerator
     * 4. Return bytes or null
     *
     * Unlike wallpaper methods, this returns raw bytes (Uint8List)
     * on success or null on failure. No ResultPayload wrapper needed
     * because there's only one success type (bytes) and one failure
     * type (null).
     */
    @Suppress("UNCHECKED_CAST")
    private fun handleGetVideoThumbnail(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                // --- Step 1: Parse arguments ---

                val args = call.arguments as? Map<String, Any?>
                if (args == null) {
                    Log.e(TAG, "getVideoThumbnail: null or invalid arguments")
                    result.success(null)
                    return@launch
                }

                val source = args["source"] as? Map<*, *>
                if (source == null) {
                    Log.e(TAG, "getVideoThumbnail: missing source")
                    result.success(null)
                    return@launch
                }

                val sourceType = source["type"] as? String
                if (sourceType == null) {
                    Log.e(TAG, "getVideoThumbnail: missing source type")
                    result.success(null)
                    return@launch
                }

                val sourcePath = source["path"] as? String
                if (sourcePath.isNullOrBlank()) {
                    Log.e(TAG, "getVideoThumbnail: missing source path")
                    result.success(null)
                    return@launch
                }

                val quality = (args["quality"] as? Int) ?: 30
                val enableCache = (args["cache"] as? Boolean) ?: true
                val goToHome = (args["goToHome"] as? Boolean) ?: false

                if (goToHome) {
                    launchHomeScreen()
                }

                Log.d(TAG, "getVideoThumbnail: type=$sourceType, "
                        + "path=$sourcePath, quality=$quality, cache=$enableCache, "
                        + "goToHome=$goToHome")

                // --- Step 2: Resolve source to local file ---

                val file = try {
                    sourceResolver.resolve(sourceType, sourcePath)
                } catch (e: SourceResolver.SourceNotFoundException) {
                    Log.e(TAG, "getVideoThumbnail: source not found", e)
                    result.success(null)
                    return@launch
                } catch (e: CacheManager.DownloadException) {
                    Log.e(TAG, "getVideoThumbnail: download failed", e)
                    result.success(null)
                    return@launch
                } catch (e: Exception) {
                    Log.e(TAG, "getVideoThumbnail: resolve failed", e)
                    result.success(null)
                    return@launch
                }

                // --- Step 3: Generate thumbnail ---

                val thumbnailBytes = thumbnailGenerator.generate(
                    videoFile = file,
                    sourceKey = sourcePath,
                    quality = quality,
                    enableCache = enableCache,
                )

                if (thumbnailBytes != null) {
                    Log.d(TAG, "getVideoThumbnail: success, "
                            + "${thumbnailBytes.size} bytes")
                } else {
                    Log.w(TAG, "getVideoThumbnail: generation returned null")
                }

                // --- Step 4: Return bytes ---

                result.success(thumbnailBytes)

            } catch (e: Exception) {
                Log.e(TAG, "getVideoThumbnail: unexpected exception", e)
                result.success(null)
            }
        }
    }

    // ================================================================
    // Cache Management
    // ================================================================

    private fun handleClearCache(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        scope.launch {
            if (shouldGoToHome(call)) {
                launchHomeScreen()
            }
            try {
                val success = cacheManager.clearAll()
                result.success(
                    ResultPayload(
                        success = success,
                        message = if (success) "Cache cleared successfully"
                        else "Some cache files could not be deleted",
                        errorCode = if (success) "none" else "cacheFailed",
                    ).toMap()
                )
            } catch (e: Exception) {
                Log.e(TAG, "clearCache failed", e)
                result.success(
                    ResultPayload.error(
                        "Failed to clear cache: ${e.message}",
                        "cacheFailed"
                    ).toMap()
                )
            }
        }
    }

    private fun handleGetCacheSize(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        scope.launch {
            if (shouldGoToHome(call)) {
                launchHomeScreen()
            }
            try {
                val size = cacheManager.totalSize()
                result.success(size)
            } catch (e: Exception) {
                Log.e(TAG, "getCacheSize failed", e)
                result.success(0L)
            }
        }
    }

    private fun handleSetMaxCacheSize(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        try {
            if (shouldGoToHome(call)) {
                launchHomeScreen()
            }

            val maxBytes: Long = when (val raw = call.argument<Any>("maxBytes")) {
                is Long -> raw
                is Int -> raw.toLong()
                is Double -> raw.toLong()
                else -> {
                    result.success(null)
                    return
                }
            }

            if (maxBytes > 0) {
                cacheManager.maxCacheSize = maxBytes
                Log.d(TAG, "Max cache size set to $maxBytes bytes")
            }

            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "setMaxCacheSize failed", e)
            result.success(null)
        }
    }

    // ================================================================
    // Helpers
    // ================================================================

    @Suppress("UNCHECKED_CAST")
    private fun shouldGoToHome(call: MethodCall): Boolean {
        val args = call.arguments as? Map<String, Any?> ?: return false
        return args["goToHome"] as? Boolean ?: false
    }

    private fun saveVideoWallpaperConfig(file: File, config: WallpaperConfig): Boolean {
        val prefs = context.getSharedPreferences(
            VideoWallpaperService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        return prefs.edit()
            .putString(VideoWallpaperService.KEY_VIDEO_PATH, file.absolutePath)
            .putBoolean(VideoWallpaperService.KEY_ENABLE_AUDIO, config.enableAudio)
            .putBoolean(VideoWallpaperService.KEY_LOOP, config.loop)
            .commit()
    }

    private suspend fun persistVideoForWallpaperService(sourceFile: File): File =
        withContext(Dispatchers.IO) {
            val destinationDir = File(context.filesDir, LIVE_VIDEO_DIR_NAME)
            if (!destinationDir.exists() && !destinationDir.mkdirs()) {
                throw IllegalStateException(
                    "Could not create live wallpaper storage directory."
                )
            }

            val extension = sourceFile.extension
                .takeIf { it.isNotBlank() }
                ?.lowercase(Locale.US)
                ?: "mp4"

            val destinationFile = File(
                destinationDir,
                "$ACTIVE_LIVE_VIDEO_BASENAME.$extension"
            )

            if (sourceFile.absolutePath != destinationFile.absolutePath) {
                val tempFile = File(
                    destinationDir,
                    "$ACTIVE_LIVE_VIDEO_BASENAME.tmp"
                )

                sourceFile.inputStream().use { input ->
                    tempFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }

                if (!tempFile.exists() || tempFile.length() == 0L) {
                    tempFile.delete()
                    throw IllegalStateException(
                        "Prepared live wallpaper file is empty."
                    )
                }

                if (!tempFile.renameTo(destinationFile)) {
                    tempFile.copyTo(destinationFile, overwrite = true)
                    tempFile.delete()
                }
            }

            destinationDir.listFiles()
                ?.filter {
                    it.name.startsWith("$ACTIVE_LIVE_VIDEO_BASENAME.") &&
                            it.absolutePath != destinationFile.absolutePath
                }
                ?.forEach { staleFile ->
                    if (!staleFile.delete()) {
                        Log.w(
                            TAG,
                            "Failed to delete stale live wallpaper file: "
                                    + staleFile.absolutePath
                        )
                    }
                }

            destinationFile
        }

    private fun isVideoSource(sourcePath: String, file: File): Boolean {
        val mimeFromSource = guessMimeType(sourcePath)
        if (mimeFromSource?.startsWith("video/") == true) return true
        if (mimeFromSource?.startsWith("image/") == true) return false

        val mimeFromFile = guessMimeType(file.name)
        if (mimeFromFile?.startsWith("video/") == true) return true
        if (mimeFromFile?.startsWith("image/") == true) return false

        val candidate = "$sourcePath ${file.name}".lowercase(Locale.US)
        val videoHints = listOf(
            ".mp4", ".webm", ".mkv", ".3gp", ".avi", ".mov", ".m4v"
        )
        return videoHints.any { candidate.contains(it) }
    }

    private fun guessMimeType(pathOrUrl: String): String? {
        val extension = MimeTypeMap.getFileExtensionFromUrl(pathOrUrl)
            ?.lowercase(Locale.US)
            ?.takeIf { it.isNotBlank() }
            ?: return null
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
    }

    private fun buildShareableUri(file: File): Uri? {
        val authority = "${context.packageName}.flutterwallpaperplus.fileprovider"
        return try {
            FileProvider.getUriForFile(context, authority, file)
        } catch (e: IllegalArgumentException) {
            Log.e(
                TAG,
                "FileProvider could not serve URI for ${file.absolutePath}. " +
                        "Check file_paths configuration.",
                e
            )
            null
        }
    }

    private fun showToastIfNeeded(show: Boolean, message: String) {
        if (!show) return
        try {
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to show toast: ${e.message}")
        }
    }

    private fun launchHomeScreen(): Boolean {
        return try {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(homeIntent)
            true
        } catch (e: Exception) {
            Log.w(TAG, "Failed to launch home screen", e)
            false
        }
    }

    private fun isAppInternalPath(path: String): Boolean {
        val appPaths = mutableListOf<String>()
        context.cacheDir?.absolutePath?.let { appPaths.add(it) }
        context.filesDir?.absolutePath?.let { appPaths.add(it) }
        context.dataDir?.absolutePath?.let { appPaths.add(it) }
        context.getExternalFilesDir(null)?.absolutePath?.let { appPaths.add(it) }
        context.externalCacheDir?.absolutePath?.let { appPaths.add(it) }
        return appPaths.any { appPath -> path.startsWith(appPath) }
    }

    fun dispose() {
        Log.d(TAG, "Disposing method handler")
        scope.cancel("Plugin detached from engine")
    }
}
