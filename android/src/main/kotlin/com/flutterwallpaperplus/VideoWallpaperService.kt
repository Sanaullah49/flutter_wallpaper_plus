package com.flutterwallpaperplus

import android.content.SharedPreferences
import android.service.wallpaper.WallpaperService
import android.util.Log
import android.view.SurfaceHolder

/**
 * Android WallpaperService for video (live) wallpapers.
 *
 * This service is declared in AndroidManifest.xml and is bound by the
 * Android system when the user selects it as their live wallpaper.
 *
 * Lifecycle:
 * 1. User selects the live wallpaper via the system picker
 * 2. Android binds to this service
 * 3. [onCreateEngine] creates a new [VideoWallpaperEngine]
 * 4. The engine manages the SurfaceHolder and ExoPlayer via [VideoRenderer]
 * 5. The service runs independently of the Flutter app — survives app kill
 * 6. The service is destroyed when the user changes wallpaper
 *
 * Configuration persistence:
 * - Video path, audio, and loop settings are stored in SharedPreferences
 * - Written by WallpaperMethodHandler when setVideoWallpaper is called
 * - Read by VideoWallpaperEngine when the surface is created
 * - This allows the service to start with correct settings after app kill
 *
 * Key robustness features:
 * - Every callback wraps operations in try-catch
 * - Player errors trigger recovery (seek to start + re-prepare)
 * - Surface destruction properly pauses and detaches
 * - Screen rotation is handled via onSurfaceChanged
 * - Visibility changes pause/resume to save battery
 *
 * Important Android notes:
 * - The service must be declared with BIND_WALLPAPER permission
 * - The intent-filter must include WallpaperService action
 * - The meta-data must point to the XML wallpaper descriptor
 * - Touch events are disabled (passed through to launcher)
 */
class VideoWallpaperService : WallpaperService() {

    companion object {
        private const val TAG = "VideoWallpaperService"

        /**
         * SharedPreferences file name used by both the method handler
         * (writer) and the wallpaper service (reader).
         */
        const val PREFS_NAME = "flutter_wallpaper_plus_prefs"

        /** Key for the absolute path to the video file. */
        const val KEY_VIDEO_PATH = "video_path"

        /** Key for the audio enabled flag. */
        const val KEY_ENABLE_AUDIO = "enable_audio"

        /** Key for the loop enabled flag. */
        const val KEY_LOOP = "loop"
    }

    override fun onCreateEngine(): Engine {
        Log.d(TAG, "Creating wallpaper engine")
        return VideoWallpaperEngine()
    }

    /**
     * Inner Engine class that manages the video wallpaper rendering.
     *
     * Each Engine instance corresponds to one "instance" of the wallpaper.
     * On most devices there is one instance, but some (e.g., Samsung with
     * separate home/lock wallpapers) may create multiple.
     *
     * The Engine lifecycle:
     * - onCreate → called once when engine is created
     * - onSurfaceCreated → surface is ready for rendering
     * - onSurfaceChanged → dimensions changed (rotation)
     * - onVisibilityChanged → wallpaper shown/hidden
     * - onSurfaceDestroyed → surface is being destroyed
     * - onDestroy → engine is being destroyed
     */
    inner class VideoWallpaperEngine : Engine() {

        private var videoRenderer: VideoRenderer? = null

        /**
         * SharedPreferences instance, lazily loaded.
         * Uses the application context which is always available.
         */
        private val prefs: SharedPreferences by lazy {
            applicationContext.getSharedPreferences(
                PREFS_NAME,
                MODE_PRIVATE
            )
        }

        // ============================================================
        // Lifecycle Callbacks
        // ============================================================

        override fun onCreate(surfaceHolder: SurfaceHolder?) {
            super.onCreate(surfaceHolder)
            Log.d(TAG, "Engine onCreate")

            // Disable touch events — let them pass through to the launcher
            // This prevents the wallpaper from intercepting touches meant
            // for app icons, widgets, etc.
            setTouchEventsEnabled(false)
        }

        /**
         * Called when the surface is created and ready for rendering.
         *
         * This is where we:
         * 1. Read the video configuration from SharedPreferences
         * 2. Create the VideoRenderer
         * 3. Initialize ExoPlayer with the video file
         *
         * If the video path is not set (prefs empty), we log a warning
         * and skip initialization. This can happen if the service is
         * restored after a system restart but prefs were cleared.
         */
        override fun onSurfaceCreated(holder: SurfaceHolder) {
            super.onSurfaceCreated(holder)
            Log.d(TAG, "Engine onSurfaceCreated")

            try {
                // Read configuration from SharedPreferences
                val videoPath = prefs.getString(KEY_VIDEO_PATH, null)
                val enableAudio = prefs.getBoolean(KEY_ENABLE_AUDIO, false)
                val loop = prefs.getBoolean(KEY_LOOP, true)

                if (videoPath.isNullOrBlank()) {
                    Log.w(TAG, "No video path configured in SharedPreferences. "
                            + "The wallpaper will show a blank surface.")
                    return
                }

                // Verify the video file still exists
                val videoFile = java.io.File(videoPath)
                if (!videoFile.exists()) {
                    Log.e(TAG, "Video file no longer exists: $videoPath")
                    return
                }

                Log.d(TAG, "Initializing renderer: path=$videoPath, "
                        + "audio=$enableAudio, loop=$loop")

                // Create and configure the renderer
                val renderer = VideoRenderer(applicationContext).apply {
                    audioEnabled = enableAudio
                    loopEnabled = loop
                }

                // Initialize with the video file and surface
                renderer.initialize(videoPath, holder)

                videoRenderer = renderer

            } catch (e: Exception) {
                Log.e(TAG, "Error in onSurfaceCreated", e)
                // Don't crash — the wallpaper will just show blank
            }
        }

        /**
         * Called when the surface dimensions change.
         *
         * This happens during:
         * - Screen rotation
         * - Display mode changes
         * - Foldable phone fold/unfold
         *
         * We delegate to the renderer which re-attaches the surface.
         */
        override fun onSurfaceChanged(
            holder: SurfaceHolder,
            format: Int,
            width: Int,
            height: Int
        ) {
            super.onSurfaceChanged(holder, format, width, height)
            Log.d(TAG, "Engine onSurfaceChanged: ${width}x${height}")

            try {
                videoRenderer?.onSurfaceChanged(holder, format, width, height)
            } catch (e: Exception) {
                Log.e(TAG, "Error in onSurfaceChanged", e)
            }
        }

        /**
         * Called when the wallpaper becomes visible or invisible.
         *
         * Visible = home screen is showing (user sees the wallpaper)
         * Invisible = an app is in the foreground
         *
         * We pause/resume the player to save battery when not visible.
         * This is the single most important battery optimization for
         * a live wallpaper.
         */
        override fun onVisibilityChanged(visible: Boolean) {
            super.onVisibilityChanged(visible)
            Log.d(TAG, "Engine onVisibilityChanged: $visible")

            try {
                videoRenderer?.onVisibilityChanged(visible)
            } catch (e: Exception) {
                Log.e(TAG, "Error in onVisibilityChanged", e)
            }
        }

        /**
         * Called when the surface is being destroyed.
         *
         * This can happen when:
         * - The wallpaper is being changed
         * - The service is being stopped
         * - The system needs to reclaim resources
         *
         * We must stop rendering to the surface before it's destroyed,
         * otherwise the player will crash trying to render to a dead surface.
         */
        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            Log.d(TAG, "Engine onSurfaceDestroyed")

            try {
                videoRenderer?.onSurfaceDestroyed()
            } catch (e: Exception) {
                Log.e(TAG, "Error in onSurfaceDestroyed", e)
            }

            super.onSurfaceDestroyed(holder)
        }

        /**
         * Called when the engine is being destroyed.
         *
         * We fully release the player and all resources.
         * After this, the engine cannot be used again.
         */
        override fun onDestroy() {
            Log.d(TAG, "Engine onDestroy")

            try {
                videoRenderer?.release()
                videoRenderer = null
            } catch (e: Exception) {
                Log.e(TAG, "Error in onDestroy", e)
            }

            super.onDestroy()
        }

        // ============================================================
        // Optional Overrides (handled gracefully)
        // ============================================================

        /**
         * Called when the wallpaper offset changes (scrolling between
         * home screen pages).
         *
         * We don't use this for video wallpapers, but override it to
         * prevent any default behavior that might cause issues.
         */
        override fun onOffsetsChanged(
            xOffset: Float,
            yOffset: Float,
            xOffsetStep: Float,
            yOffsetStep: Float,
            xPixelOffset: Int,
            yPixelOffset: Int
        ) {
            // Intentionally empty — video wallpapers don't scroll
        }
    }
}