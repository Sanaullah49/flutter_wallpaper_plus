package com.flutterwallpaperplus

import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast
import com.flutterwallpaperplus.models.ResultPayload
import com.flutterwallpaperplus.models.WallpaperConfig
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

/**
 * Central method call handler for all plugin operations.
 *
 * Architecture:
 * - Each method runs inside a coroutine on the appropriate dispatcher
 * - IO operations use Dispatchers.IO via the manager classes
 * - Results are posted back on Dispatchers.Main via the scope
 * - SupervisorJob ensures one failed coroutine doesn't cancel others
 * - The scope is cancelled in [dispose] to prevent leaks
 *
 * Error handling strategy:
 * - Every handler catches all exceptions internally
 * - Errors are returned as ResultPayload, never as MethodChannel errors
 * - This ensures the Dart side always gets a structured response
 * - Toast is shown on main thread after the result is determined
 */
class WallpaperMethodHandler(
    private val context: Context,
    private val flutterAssets: FlutterPlugin.FlutterAssets,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "WallpaperMethodHandler"
    }

    /**
     * Coroutine scope for all async operations.
     *
     * - SupervisorJob: child failures don't cancel siblings
     * - Dispatchers.Main.immediate: results posted on main thread
     *   for MethodChannel.Result compatibility
     */
    private val scope = CoroutineScope(
        SupervisorJob() + Dispatchers.Main.immediate
    )

    /**
     * Lazy-initialized managers — created only when first needed.
     */
    private val cacheManager: CacheManager by lazy {
        CacheManager(context)
    }

    private val sourceResolver: SourceResolver by lazy {
        SourceResolver(context, cacheManager, flutterAssets)
    }

    private val imageWallpaperManager: ImageWallpaperManager by lazy {
        ImageWallpaperManager(context)
    }

    // ThumbnailGenerator will be added in Phase 4

    /**
     * Routes incoming method calls to the appropriate handler.
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "Method called: ${call.method}")

        when (call.method) {
            "setImageWallpaper" -> handleSetImageWallpaper(call, result)
            "setVideoWallpaper" -> handleSetVideoWallpaper(call, result)
            "getVideoThumbnail" -> handleGetVideoThumbnail(call, result)
            "clearCache" -> handleClearCache(result)
            "getCacheSize" -> handleGetCacheSize(result)
            "setMaxCacheSize" -> handleSetMaxCacheSize(call, result)
            else -> {
                Log.w(TAG, "Unknown method: ${call.method}")
                result.notImplemented()
            }
        }
    }

    // ================================================================
    // PHASE 2 — Image Wallpaper (FULLY IMPLEMENTED)
    // ================================================================

    @Suppress("UNCHECKED_CAST")
    private fun handleSetImageWallpaper(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                val args = call.arguments as? Map<String, Any?>
                if (args == null) {
                    Log.e(TAG, "setImageWallpaper: null or invalid arguments")
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
                    Log.e(TAG, "setImageWallpaper: invalid config", e)
                    result.success(
                        ResultPayload.error(
                            "Invalid configuration: ${e.message}",
                            "applyFailed"
                        ).toMap()
                    )
                    return@launch
                }

                if (!config.isValid()) {
                    Log.e(TAG, "setImageWallpaper: config validation failed")
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

                // Check permissions
                if (!PermissionHelper.hasWallpaperPermission(context)) {
                    Log.w(TAG, "setImageWallpaper: SET_WALLPAPER not granted")
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

                // Resolve source to local file
                val file = try {
                    sourceResolver.resolve(config.sourceType, config.sourcePath)
                } catch (e: SourceResolver.SourceNotFoundException) {
                    Log.e(TAG, "setImageWallpaper: source not found", e)
                    val payload = ResultPayload.error(
                        e.message ?: "Source not found",
                        "sourceNotFound"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                } catch (e: CacheManager.DownloadException) {
                    Log.e(TAG, "setImageWallpaper: download failed", e)
                    val payload = ResultPayload.error(
                        e.message ?: "Download failed",
                        "downloadFailed"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                // Apply wallpaper
                val payload = imageWallpaperManager.setWallpaper(file, config)

                val toastMessage = if (payload.success) {
                    config.successMessage
                } else {
                    config.errorMessage
                }
                showToastIfNeeded(config.showToast, toastMessage)

                result.success(payload.toMap())

            } catch (e: Exception) {
                Log.e(TAG, "setImageWallpaper: unexpected exception", e)
                result.success(
                    ResultPayload.error(
                        "Unexpected error: ${e.message ?: "Unknown"}",
                        "unknown"
                    ).toMap()
                )
            }
        }
    }

    // ================================================================
    // PHASE 3 — Video Wallpaper (FULLY IMPLEMENTED)
    // ================================================================

    /**
     * Handles the setVideoWallpaper method call.
     *
     * Flow:
     * 1. Parse arguments into WallpaperConfig
     * 2. Check live wallpaper support
     * 3. Check permissions
     * 4. Resolve source to local file (download if URL, extract if asset)
     * 5. Persist config to SharedPreferences (for service to read)
     * 6. Launch the system live wallpaper chooser intent
     * 7. Return structured result
     *
     * The actual video playback is handled by [VideoWallpaperService]
     * which runs independently of this handler and the Flutter app.
     *
     * Intent strategy:
     * - Primary: ACTION_CHANGE_LIVE_WALLPAPER with EXTRA_LIVE_WALLPAPER_COMPONENT
     *   This directly opens our specific wallpaper for confirmation.
     * - Fallback: ACTION_LIVE_WALLPAPER_CHOOSER
     *   This opens the general live wallpaper picker (user must find ours).
     */
    @Suppress("UNCHECKED_CAST")
    private fun handleSetVideoWallpaper(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                // --- Step 1: Parse arguments ---

                val args = call.arguments as? Map<String, Any?>
                if (args == null) {
                    Log.e(TAG, "setVideoWallpaper: null or invalid arguments")
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
                    Log.e(TAG, "setVideoWallpaper: invalid config", e)
                    result.success(
                        ResultPayload.error(
                            "Invalid configuration: ${e.message}",
                            "applyFailed"
                        ).toMap()
                    )
                    return@launch
                }

                if (!config.isValid()) {
                    Log.e(TAG, "setVideoWallpaper: config validation failed")
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

                // --- Step 2: Check live wallpaper support ---

                if (!PermissionHelper.supportsLiveWallpaper(context)) {
                    Log.w(TAG, "setVideoWallpaper: live wallpaper not supported")
                    val payload = ResultPayload.error(
                        "Live wallpapers are not supported on this device. "
                                + "This may be due to Android Go edition, "
                                + "manufacturer restrictions, or missing system feature.",
                        "unsupported"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                // --- Step 3: Check permissions ---

                if (config.sourceType == "file") {
                    if (!isAppInternalPath(config.sourcePath) &&
                        !PermissionHelper.hasStorageReadPermission(context)
                    ) {
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

                // --- Step 4: Resolve source to local file ---

                Log.d(TAG, "setVideoWallpaper: resolving source "
                        + "type=${config.sourceType}, path=${config.sourcePath}")

                val file = try {
                    sourceResolver.resolve(config.sourceType, config.sourcePath)
                } catch (e: SourceResolver.SourceNotFoundException) {
                    Log.e(TAG, "setVideoWallpaper: source not found", e)
                    val payload = ResultPayload.error(
                        e.message ?: "Source not found",
                        "sourceNotFound"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                } catch (e: CacheManager.DownloadException) {
                    Log.e(TAG, "setVideoWallpaper: download failed", e)
                    val payload = ResultPayload.error(
                        e.message ?: "Download failed",
                        "downloadFailed"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                Log.d(TAG, "setVideoWallpaper: source resolved to "
                        + "${file.absolutePath} (${file.length()} bytes)")

                // --- Step 5: Persist config to SharedPreferences ---
                //
                // The VideoWallpaperService runs in a separate process/lifecycle
                // and needs to know which video to play, whether to enable
                // audio, and whether to loop. SharedPreferences is the
                // simplest IPC mechanism that survives app kill.

                val prefs = context.getSharedPreferences(
                    VideoWallpaperService.PREFS_NAME,
                    Context.MODE_PRIVATE
                )

                val saved = prefs.edit()
                    .putString(
                        VideoWallpaperService.KEY_VIDEO_PATH,
                        file.absolutePath
                    )
                    .putBoolean(
                        VideoWallpaperService.KEY_ENABLE_AUDIO,
                        config.enableAudio
                    )
                    .putBoolean(
                        VideoWallpaperService.KEY_LOOP,
                        config.loop
                    )
                    .commit() // Use commit() not apply() — we need confirmation

                if (!saved) {
                    Log.e(TAG, "setVideoWallpaper: failed to save preferences")
                    val payload = ResultPayload.error(
                        "Failed to save wallpaper configuration",
                        "applyFailed"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                Log.d(TAG, "setVideoWallpaper: config saved to SharedPreferences")

                // --- Step 6: Launch live wallpaper chooser ---

                val launchResult = launchLiveWallpaperChooser()

                if (launchResult.success) {
                    showToastIfNeeded(config.showToast, config.successMessage)
                    result.success(
                        ResultPayload.success(config.successMessage).toMap()
                    )
                } else {
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(launchResult.toMap())
                }

            } catch (e: Exception) {
                Log.e(TAG, "setVideoWallpaper: unexpected exception", e)
                result.success(
                    ResultPayload.error(
                        "Unexpected error: ${e.message ?: "Unknown"}",
                        "unknown"
                    ).toMap()
                )
            }
        }
    }

    /**
     * Attempts to launch the system live wallpaper chooser.
     *
     * Strategy:
     * 1. Try ACTION_CHANGE_LIVE_WALLPAPER with our specific component.
     *    This directly shows our wallpaper for confirmation (best UX).
     *
     * 2. If that fails, try ACTION_LIVE_WALLPAPER_CHOOSER.
     *    This opens the general live wallpaper list (user must find ours).
     *
     * 3. If both fail, return an error.
     *    This can happen on heavily customized OEM launchers.
     */
    private fun launchLiveWallpaperChooser(): ResultPayload {
        // Strategy 1: Direct component intent
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
            Log.d(TAG, "Launched direct live wallpaper chooser")
            return ResultPayload.success("Live wallpaper chooser opened")

        } catch (e: Exception) {
            Log.w(TAG, "Direct chooser failed, trying fallback", e)
        }

        // Strategy 2: General live wallpaper picker
        try {
            val fallbackIntent = Intent(
                WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            context.startActivity(fallbackIntent)
            Log.d(TAG, "Launched fallback live wallpaper chooser")
            return ResultPayload.success(
                "Wallpaper picker opened — please select Video Wallpaper"
            )

        } catch (e: Exception) {
            Log.e(TAG, "Fallback chooser also failed", e)
        }

        // Both strategies failed
        return ResultPayload.error(
            "Could not open the wallpaper picker. "
                    + "This device may not support live wallpapers, "
                    + "or the launcher may block wallpaper changes.",
            "unsupported"
        )
    }

    // ================================================================
    // PHASE 4 PLACEHOLDER — Thumbnail
    // ================================================================

    @Suppress("UNCHECKED_CAST")
    private fun handleGetVideoThumbnail(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                // TODO: Phase 4 implementation
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "getVideoThumbnail failed", e)
                result.success(null)
            }
        }
    }

    // ================================================================
    // Cache Management
    // ================================================================

    private fun handleClearCache(result: MethodChannel.Result) {
        scope.launch {
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

    private fun handleGetCacheSize(result: MethodChannel.Result) {
        scope.launch {
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

    private fun showToastIfNeeded(show: Boolean, message: String) {
        if (!show) return
        try {
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to show toast: ${e.message}")
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

    // ================================================================
    // Lifecycle
    // ================================================================

    fun dispose() {
        Log.d(TAG, "Disposing method handler")
        scope.cancel("Plugin detached from engine")
    }
}