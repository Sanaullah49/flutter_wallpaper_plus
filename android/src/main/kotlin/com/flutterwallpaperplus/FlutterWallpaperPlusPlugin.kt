package com.flutterwallpaperplus

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/**
 * Entry point for the flutter_wallpaper_plus Android plugin.
 *
 * Lifecycle:
 * 1. Flutter engine loads this class via reflection
 *    (configured in pubspec.yaml pluginClass).
 * 2. [onAttachedToEngine] is called — we register the MethodChannel
 *    and create the handler with proper context.
 * 3. [onDetachedFromEngine] is called when the engine is torn down —
 *    we clean up all resources.
 *
 * Design notes:
 * - We store references to channel and handler as nullable fields
 *   and null them out on detach to prevent memory leaks.
 * - The FlutterPlugin.FlutterAssets reference is captured from the
 *   binding and passed to SourceResolver for asset path resolution.
 * - We use applicationContext (not activity context) because the
 *   WallpaperService runs independently of any Activity.
 */
class FlutterWallpaperPlusPlugin : FlutterPlugin {

    companion object {
        private const val TAG = "WallpaperPlusPlugin"

        /**
         * Method channel name — must match the Dart side exactly.
         * Uses reverse domain notation for uniqueness across plugins.
         */
        const val CHANNEL_NAME = "com.flutterwallpaperplus/methods"
    }

    /** The method channel instance, created on attach. */
    private var channel: MethodChannel? = null

    /** The method call handler, created on attach. */
    private var handler: WallpaperMethodHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Plugin attached to engine")

        // Create the method channel with the binding's binary messenger
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)

        // Create the handler with application context and flutter assets
        // We use applicationContext because:
        // 1. It outlives any Activity
        // 2. The WallpaperService needs it
        // 3. It's safe for SharedPreferences, cache dir, etc.
        handler = WallpaperMethodHandler(
            context = binding.applicationContext,
            flutterAssets = binding.flutterAssets,
        )

        // Register the handler
        channel?.setMethodCallHandler(handler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Plugin detached from engine")

        // Dispose the handler first (cancels coroutines)
        handler?.dispose()
        handler = null

        // Unregister the channel handler
        channel?.setMethodCallHandler(null)
        channel = null
    }
}