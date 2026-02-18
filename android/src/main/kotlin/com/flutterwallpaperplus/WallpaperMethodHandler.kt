package com.flutterwallpaperplus

import android.content.Context
import android.util.Log
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
 * - IO operations use Dispatchers.IO
 * - Results are posted back on Dispatchers.Main via the scope
 * - SupervisorJob ensures one failed coroutine doesn't cancel others
 * - The scope is cancelled in [dispose] to prevent leaks
 *
 * Error handling strategy:
 * - Every handler catches all exceptions internally
 * - Errors are returned as ResultPayload, never as MethodChannel errors
 * - This ensures the Dart side always gets a structured response
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

    // ImageWallpaperManager will be added in Phase 2
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
    // PHASE 2 PLACEHOLDER — Image Wallpaper
    // ================================================================

    @Suppress("UNCHECKED_CAST")
    private fun handleSetImageWallpaper(
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

                // TODO: Phase 2 implementation
                // 1. Resolve source to local file
                // 2. Apply via ImageWallpaperManager
                // 3. Show toast
                // 4. Return result

                result.success(
                    ResultPayload.error(
                        "Image wallpaper not yet implemented",
                        "unsupported"
                    ).toMap()
                )

            } catch (e: Exception) {
                Log.e(TAG, "setImageWallpaper failed", e)
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
                // 1. Parse source from args
                // 2. Resolve source to local file
                // 3. Generate thumbnail via ThumbnailGenerator
                // 4. Return bytes or null

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