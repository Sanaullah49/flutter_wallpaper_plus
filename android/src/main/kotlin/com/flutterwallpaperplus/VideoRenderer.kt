package com.flutterwallpaperplus

import android.content.Context
import android.util.Log
import android.view.SurfaceHolder
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.ExoPlayer

/**
 * Manages ExoPlayer lifecycle for video wallpaper rendering.
 *
 * This class is the bridge between Android's SurfaceHolder (provided by
 * WallpaperService.Engine) and Media3 ExoPlayer.
 *
 * Design decisions:
 *
 * 1. Player is created fresh in [initialize] and fully released in [release].
 *    There is no player pooling because the WallpaperService has a very
 *    different lifecycle than an Activity — it can live for days.
 *
 * 2. On visibility change, we pause/play rather than release/recreate.
 *    This provides instant resume when the user returns to the home screen
 *    while saving CPU/battery when an app is in the foreground.
 *
 * 3. Surface changes (rotation, size) are handled by simply re-attaching
 *    the surface holder. ExoPlayer handles scaling internally via its
 *    video renderer.
 *
 * 4. All player errors are caught and logged but never crash the service.
 *    A crashing live wallpaper service forces the user to the default
 *    wallpaper — very bad UX.
 *
 * 5. Audio volume is set to 0.0f or 1.0f (not removed from the pipeline).
 *    This allows toggling audio without rebuilding the player.
 *
 * 6. Loop is implemented via Player.REPEAT_MODE_ALL which provides
 *    seamless looping with no gap between iterations.
 */
class VideoRenderer(private val context: Context) {

    companion object {
        private const val TAG = "VideoRenderer"
    }

    private var player: ExoPlayer? = null

    /**
     * Whether audio is enabled.
     * Can be changed at any time — takes effect immediately.
     */
    @Volatile
    var audioEnabled: Boolean = false
        set(value) {
            field = value
            player?.volume = if (value) 1.0f else 0.0f
            Log.d(TAG, "Audio ${if (value) "enabled" else "disabled"}")
        }

    /**
     * Whether the video loops seamlessly.
     * Can be changed at any time — takes effect immediately.
     */
    @Volatile
    var loopEnabled: Boolean = true
        set(value) {
            field = value
            player?.repeatMode = if (value) {
                Player.REPEAT_MODE_ALL
            } else {
                Player.REPEAT_MODE_OFF
            }
            Log.d(TAG, "Loop ${if (value) "enabled" else "disabled"}")
        }

    /**
     * Whether the renderer currently has an active player.
     */
    val isActive: Boolean
        get() = player != null

    /**
     * Initializes the ExoPlayer with a video file and output surface.
     *
     * Safe to call multiple times — releases any existing player first.
     *
     * @param videoPath Absolute path to the local video file.
     * @param surfaceHolder The SurfaceHolder from WallpaperService.Engine.
     */
    fun initialize(videoPath: String, surfaceHolder: SurfaceHolder) {
        Log.d(TAG, "Initializing with video: $videoPath")

        // Release any existing player
        release()

        try {
            val exoPlayer = ExoPlayer.Builder(context)
                .build()
                .apply {
                    // Attach the surface for video output
                    setVideoSurfaceHolder(surfaceHolder)

                    // Configure audio
                    volume = if (audioEnabled) 1.0f else 0.0f

                    // Configure looping
                    repeatMode = if (loopEnabled) {
                        Player.REPEAT_MODE_ALL
                    } else {
                        Player.REPEAT_MODE_OFF
                    }

                    // Start playback as soon as ready
                    playWhenReady = true

                    // Add error listener — log but don't crash
                    addListener(createPlayerListener())

                    // Set the media source
                    val mediaItem = MediaItem.fromUri("file://$videoPath")
                    setMediaItem(mediaItem)

                    // Start preparing (async — will play when ready)
                    prepare()
                }

            player = exoPlayer
            Log.d(TAG, "Player initialized successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize player", e)
            release()
        }
    }

    /**
     * Called when the wallpaper surface is created or recreated.
     *
     * Re-attaches the surface holder to the player and starts playback.
     */
    fun onSurfaceAvailable(surfaceHolder: SurfaceHolder) {
        Log.d(TAG, "Surface available")
        try {
            player?.setVideoSurfaceHolder(surfaceHolder)
            player?.play()
        } catch (e: Exception) {
            Log.e(TAG, "Error attaching surface", e)
        }
    }

    /**
     * Called when the surface dimensions change (e.g., screen rotation).
     *
     * ExoPlayer handles video scaling internally through the surface holder,
     * so we just need to re-attach it.
     */
    fun onSurfaceChanged(
        surfaceHolder: SurfaceHolder,
        format: Int,
        width: Int,
        height: Int
    ) {
        Log.d(TAG, "Surface changed: ${width}x${height}, format=$format")
        try {
            player?.setVideoSurfaceHolder(surfaceHolder)
        } catch (e: Exception) {
            Log.e(TAG, "Error on surface change", e)
        }
    }

    /**
     * Called when the surface is destroyed.
     *
     * Pauses playback and detaches the surface to prevent rendering
     * to a dead surface (which would crash).
     */
    fun onSurfaceDestroyed() {
        Log.d(TAG, "Surface destroyed")
        try {
            player?.pause()
            player?.clearVideoSurface()
        } catch (e: Exception) {
            Log.e(TAG, "Error on surface destroyed", e)
        }
    }

    /**
     * Called when the wallpaper visibility changes.
     *
     * - Visible (home screen shown): resume playback
     * - Not visible (app in foreground): pause to save battery
     *
     * This is the primary battery-saving mechanism. A video wallpaper
     * that plays while not visible wastes significant CPU and battery.
     */
    fun onVisibilityChanged(visible: Boolean) {
        Log.d(TAG, "Visibility changed: $visible")
        try {
            if (visible) {
                player?.play()
            } else {
                player?.pause()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error on visibility change", e)
        }
    }

    /**
     * Fully releases the player and all associated resources.
     *
     * After this call, [isActive] returns false and the renderer
     * cannot be used until [initialize] is called again.
     *
     * Safe to call multiple times.
     */
    fun release() {
        try {
            player?.let { p ->
                Log.d(TAG, "Releasing player")
                p.stop()
                p.clearVideoSurface()
                p.release()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error releasing player (non-critical)", e)
        } finally {
            player = null
        }
    }

    /**
     * Creates a Player.Listener that handles errors and state changes
     * without crashing the service.
     */
    private fun createPlayerListener(): Player.Listener {
        return object : Player.Listener {

            override fun onPlayerError(error: PlaybackException) {
                Log.e(TAG, "Playback error: ${error.errorCodeName} "
                        + "— ${error.message}", error)

                // Attempt recovery: seek to start and retry
                try {
                    player?.let { p ->
                        p.seekTo(0)
                        p.prepare()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Recovery failed", e)
                }
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                val stateName = when (playbackState) {
                    Player.STATE_IDLE -> "IDLE"
                    Player.STATE_BUFFERING -> "BUFFERING"
                    Player.STATE_READY -> "READY"
                    Player.STATE_ENDED -> "ENDED"
                    else -> "UNKNOWN($playbackState)"
                }
                Log.d(TAG, "Playback state: $stateName")

                // If not looping and video ended, seek to start and pause
                // so the last frame stays visible
                if (playbackState == Player.STATE_ENDED && !loopEnabled) {
                    try {
                        player?.seekTo(0)
                        player?.pause()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error handling video end", e)
                    }
                }
            }

            override fun onVideoSizeChanged(videoSize: VideoSize) {
                Log.d(TAG, "Video size: ${videoSize.width}x${videoSize.height}")
            }
        }
    }
}