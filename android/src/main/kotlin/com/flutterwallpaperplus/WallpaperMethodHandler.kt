package com.flutterwallpaperplus

import android.content.Context
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
     * This avoids unnecessary work if the user never calls certain methods.
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
     *
     * IMPORTANT: MethodChannel.Result must be called exactly once.
     * Every code path (success, error, unimplemented) must call
     * result.success(), result.error(), or result.notImplemented().
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

    /**
     * Handles the setImageWallpaper method call.
     *
     * Flow:
     * 1. Parse arguments into WallpaperConfig
     * 2. Validate config
     * 3. Check permissions
     * 4. Resolve source to local file (download if URL, extract if asset)
     * 5. Apply wallpaper via ImageWallpaperManager
     * 6. Show toast if enabled
     * 7. Return structured result
     *
     * Every step that can fail returns a ResultPayload with an
     * appropriate error code — no exceptions escape to the caller.
     */
    @Suppress("UNCHECKED_CAST")
    private fun handleSetImageWallpaper(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                // --- Step 1: Parse arguments ---

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

                // --- Step 2: Validate config ---

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

                // --- Step 3: Check permissions ---

                if (!PermissionHelper.hasWallpaperPermission(context)) {
                    Log.w(TAG, "setImageWallpaper: SET_WALLPAPER not granted")
                    val payload = ResultPayload.error(
                        "SET_WALLPAPER permission is not granted. "
                                + "This is usually auto-granted at install time. "
                                + "If you see this error, the device may have "
                                + "restrictions.",
                        "permissionDenied"
                    )
                    showToastIfNeeded(config.showToast, config.errorMessage)
                    result.success(payload.toMap())
                    return@launch
                }

                // For file sources, check storage permission if needed
                if (config.sourceType == "file") {
                    if (!isAppInternalPath(config.sourcePath) &&
                        !PermissionHelper.hasStorageReadPermission(context)
                    ) {
                        Log.w(TAG, "setImageWallpaper: storage read not granted")
                        val payload = ResultPayload.error(
                            "Storage read permission is required to access "
                                    + "files outside the app directory. "
                                    + "Request READ_EXTERNAL_STORAGE (API < 33) or "
                                    + "READ_MEDIA_IMAGES (API 33+) in your app.",
                            "permissionDenied"
                        )
                        showToastIfNeeded(config.showToast, config.errorMessage)
                        result.success(payload.toMap())
                        return@launch
                    }
                }

                // --- Step 4: Resolve source to local file ---

                Log.d(TAG, "setImageWallpaper: resolving source "
                        + "type=${config.sourceType}, path=${config.sourcePath}")

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

                Log.d(TAG, "setImageWallpaper: source resolved to "
                        + "${file.absolutePath} (${file.length()} bytes)")

                // --- Step 5: Apply wallpaper ---

                val payload = imageWallpaperManager.setWallpaper(file, config)

                // --- Step 6: Show toast ---

                val toastMessage = if (payload.success) {
                    config.successMessage
                } else {
                    config.errorMessage
                }
                showToastIfNeeded(config.showToast, toastMessage)

                // --- Step 7: Return result ---

                Log.d(TAG, "setImageWallpaper: result=${payload.success}, "
                        + "message=${payload.message}")

                result.success(payload.toMap())

            } catch (e: Exception) {
                // This catch block should never be reached because every
                // step above has its own error handling. But we include it
                // as a safety net to guarantee result is always called.
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
    // PHASE 3 PLACEHOLDER — Video Wallpaper
    // ================================================================

    @Suppress("UNCHECKED_CAST")
    private fun handleSetVideoWallpaper(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                val args = call.arguments as? Map<String, Any?>
                    ?: return@launch result.success(
                        ResultPayload.error(
                            "Invalid arguments",
                            "applyFailed"
                        ).toMap()
                    )

                val config = try {
                    WallpaperConfig.fromMap(args)
                } catch (e: IllegalArgumentException) {
                    return@launch result.success(
                        ResultPayload.error(
                            "Invalid config: ${e.message}",
                            "applyFailed"
                        ).toMap()
                    )
                }

                if (!config.isValid()) {
                    return@launch result.success(
                        ResultPayload.error(
                            "Invalid source configuration",
                            "sourceNotFound"
                        ).toMap()
                    )
                }

                // TODO: Phase 3 implementation
                // 1. Resolve source to local file
                // 2. Save config to SharedPreferences
                // 3. Launch live wallpaper chooser intent
                // 4. Return result

                result.success(
                    ResultPayload.error(
                        "Video wallpaper not yet implemented",
                        "unsupported"
                    ).toMap()
                )

            } catch (e: Exception) {
                Log.e(TAG, "setVideoWallpaper failed", e)
                result.success(
                    ResultPayload.error(
                        "Unexpected error: ${e.message}",
                        "unknown"
                    ).toMap()
                )
            }
        }
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
    // Cache management — Fully implemented in Phase 1
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
            // Handle both Int and Long from Dart
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
    // Helper Methods
    // ================================================================

    /**
     * Shows an Android Toast on the main thread if enabled.
     *
     * This is safe to call from any coroutine context because the
     * scope uses Dispatchers.Main.immediate.
     */
    private fun showToastIfNeeded(show: Boolean, message: String) {
        if (!show) return
        try {
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            // Toast can fail in rare edge cases (e.g., context destroyed)
            Log.w(TAG, "Failed to show toast: ${e.message}")
        }
    }

    /**
     * Checks whether a file path is within the app's internal directories.
     *
     * Files inside the app's own cache/files/data directories don't require
     * external storage permissions. This avoids false permission errors
     * when the user passes a path to a file the app already owns.
     *
     * Covered paths:
     * - context.cacheDir → /data/data/<pkg>/cache/
     * - context.filesDir → /data/data/<pkg>/files/
     * - context.getExternalFilesDir() → /storage/emulated/0/Android/data/<pkg>/files/
     * - context.externalCacheDir → /storage/emulated/0/Android/data/<pkg>/cache/
     */
    private fun isAppInternalPath(path: String): Boolean {
        val appPaths = mutableListOf<String>()

        // Internal storage
        context.cacheDir?.absolutePath?.let { appPaths.add(it) }
        context.filesDir?.absolutePath?.let { appPaths.add(it) }
        context.dataDir?.absolutePath?.let { appPaths.add(it) }

        // External app-specific storage
        context.getExternalFilesDir(null)?.absolutePath?.let { appPaths.add(it) }
        context.externalCacheDir?.absolutePath?.let { appPaths.add(it) }

        return appPaths.any { appPath -> path.startsWith(appPath) }
    }

    // ================================================================
    // Lifecycle
    // ================================================================

    /**
     * Cancels all running coroutines and releases resources.
     *
     * Called by the plugin's [onDetachedFromEngine].
     */
    fun dispose() {
        Log.d(TAG, "Disposing method handler")
        scope.cancel("Plugin detached from engine")
    }
}
