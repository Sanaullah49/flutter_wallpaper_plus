package com.flutterwallpaperplus

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Generates lightweight video thumbnails using MediaMetadataRetriever.
 *
 * Design decisions:
 *
 * 1. Uses MediaMetadataRetriever instead of ExoPlayer for thumbnail extraction.
 *    MediaMetadataRetriever is lighter weight, doesn't require a Surface,
 *    and is specifically designed for metadata/frame extraction.
 *
 * 2. Extracts a frame at 1 second into the video (OPTION_CLOSEST_SYNC).
 *    The first frame is often black or a loading screen. 1 second gives
 *    a more representative thumbnail. Falls back to frame at 0 if 1s fails.
 *
 * 3. Scales the bitmap down to max 480px on its largest dimension.
 *    This keeps thumbnails small (typically 5-30 KB after JPEG compression)
 *    while still being sharp enough for list/grid previews.
 *
 * 4. Uses JPEG compression rather than PNG because:
 *    - JPEG is 5-10x smaller for photographic content
 *    - Video frames are photographic by nature
 *    - Quality parameter gives fine-grained size control
 *
 * 5. Caches generated thumbnails so repeated calls return instantly.
 *    Cache key is the source path/URL (same key as the video cache).
 *
 * 6. All Bitmap objects are explicitly recycled after use to prevent
 *    memory pressure on devices with limited RAM.
 *
 * 7. Runs entirely on Dispatchers.IO — never blocks the main thread.
 */
class ThumbnailGenerator(private val cacheManager: CacheManager) {

    companion object {
        private const val TAG = "ThumbnailGenerator"

        /**
         * Maximum dimension (width or height) for generated thumbnails.
         * The bitmap is scaled proportionally so its largest dimension
         * does not exceed this value.
         */
        private const val MAX_THUMBNAIL_DIMENSION = 480

        /**
         * Time position to extract the thumbnail frame, in microseconds.
         * 1 second = 1,000,000 microseconds.
         */
        private const val FRAME_TIME_PRIMARY_US = 1_000_000L

        /**
         * Fallback time position (first frame) if primary fails.
         */
        private const val FRAME_TIME_FALLBACK_US = 0L
    }

    /**
     * Generates a compressed JPEG thumbnail from a video file.
     *
     * @param videoFile The resolved local video file.
     * @param sourceKey Unique key for caching (original source path/URL).
     *   This ensures the same source always maps to the same cache entry.
     * @param quality JPEG compression quality (1-100).
     *   Lower values = smaller file, worse quality.
     *   Recommended: 30 for list thumbnails, 60 for detail previews.
     * @param enableCache Whether to read from and write to the thumbnail cache.
     * @return Compressed JPEG bytes, or null if extraction fails.
     */
    suspend fun generate(
        videoFile: File,
        sourceKey: String,
        quality: Int = 30,
        enableCache: Boolean = true,
    ): ByteArray? = withContext(Dispatchers.IO) {

        val clampedQuality = quality.coerceIn(1, 100)

        Log.d(TAG, "Generating thumbnail: file=${videoFile.name}, "
                + "key=$sourceKey, quality=$clampedQuality, cache=$enableCache")

        // --- Step 1: Check cache ---

        if (enableCache) {
            try {
                val cached = cacheManager.getThumbnail(sourceKey)
                if (cached != null) {
                    Log.d(TAG, "Thumbnail cache hit: ${cached.size} bytes")
                    return@withContext cached
                }
            } catch (e: Exception) {
                Log.w(TAG, "Cache read failed (non-critical)", e)
                // Continue to generate — cache miss is not an error
            }
        }

        // --- Step 2: Validate file ---

        if (!videoFile.exists()) {
            Log.e(TAG, "Video file does not exist: ${videoFile.absolutePath}")
            return@withContext null
        }

        if (videoFile.length() == 0L) {
            Log.e(TAG, "Video file is empty: ${videoFile.absolutePath}")
            return@withContext null
        }

        // --- Step 3: Extract frame ---

        val retriever = MediaMetadataRetriever()
        var originalBitmap: Bitmap? = null
        var scaledBitmap: Bitmap? = null

        try {
            retriever.setDataSource(videoFile.absolutePath)

            // Try to get a frame at 1 second (more representative than first frame)
            originalBitmap = retriever.getFrameAtTime(
                FRAME_TIME_PRIMARY_US,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            )

            // Fallback: try the very first frame
            if (originalBitmap == null) {
                Log.d(TAG, "Primary frame extraction failed, trying fallback")
                originalBitmap = retriever.getFrameAtTime(
                    FRAME_TIME_FALLBACK_US,
                    MediaMetadataRetriever.OPTION_CLOSEST
                )
            }

            // Final fallback: try with no time specification
            if (originalBitmap == null) {
                Log.d(TAG, "Fallback frame extraction failed, trying default")
                originalBitmap = retriever.getFrameAtTime(
                    FRAME_TIME_FALLBACK_US,
                    MediaMetadataRetriever.OPTION_PREVIOUS_SYNC
                )
            }

            if (originalBitmap == null) {
                Log.e(TAG, "All frame extraction methods failed")
                return@withContext null
            }

            Log.d(TAG, "Frame extracted: ${originalBitmap.width}x${originalBitmap.height}")

            // --- Step 4: Scale down ---

            scaledBitmap = scaleBitmap(originalBitmap, MAX_THUMBNAIL_DIMENSION)

            Log.d(TAG, "Scaled to: ${scaledBitmap.width}x${scaledBitmap.height}")

            // --- Step 5: Compress to JPEG ---

            val bytes = compressBitmap(scaledBitmap, clampedQuality)

            if (bytes == null || bytes.isEmpty()) {
                Log.e(TAG, "JPEG compression produced empty output")
                return@withContext null
            }

            Log.d(TAG, "Compressed thumbnail: ${bytes.size} bytes "
                    + "(quality=$clampedQuality)")

            // --- Step 6: Cache ---

            if (enableCache) {
                try {
                    cacheManager.saveThumbnail(sourceKey, bytes)
                    Log.d(TAG, "Thumbnail cached successfully")
                } catch (e: Exception) {
                    Log.w(TAG, "Thumbnail cache write failed (non-critical)", e)
                    // Don't fail the whole operation because cache write failed
                }
            }

            bytes

        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "Invalid video file or unsupported format", e)
            null
        } catch (e: RuntimeException) {
            // MediaMetadataRetriever throws RuntimeException for various
            // issues: corrupt files, unsupported codecs, etc.
            Log.e(TAG, "MediaMetadataRetriever error", e)
            null
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "Out of memory during thumbnail generation", e)
            null
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error generating thumbnail", e)
            null
        } finally {
            // --- Cleanup ---

            // Recycle bitmaps to free native memory immediately
            // Only recycle scaledBitmap if it's a different object than original
            if (scaledBitmap != null && scaledBitmap !== originalBitmap) {
                scaledBitmap.recycle()
            }
            originalBitmap?.recycle()

            // Release the retriever
            try {
                retriever.release()
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing MediaMetadataRetriever", e)
            }
        }
    }

    /**
     * Scales a bitmap proportionally so its largest dimension
     * does not exceed [maxDimension].
     *
     * If the bitmap is already smaller than maxDimension on both
     * axes, it is returned as-is (no copy made).
     *
     * @param bitmap The source bitmap.
     * @param maxDimension Maximum pixels for width or height.
     * @return A new scaled bitmap, or the original if no scaling needed.
     *   The caller is responsible for recycling both bitmaps.
     */
    private fun scaleBitmap(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val width = bitmap.width
        val height = bitmap.height

        // No scaling needed
        if (width <= maxDimension && height <= maxDimension) {
            Log.d(TAG, "No scaling needed: ${width}x${height}")
            return bitmap
        }

        // Calculate scale factor to fit within maxDimension
        val scaleFactor = minOf(
            maxDimension.toFloat() / width,
            maxDimension.toFloat() / height
        )

        val newWidth = (width * scaleFactor).toInt().coerceAtLeast(1)
        val newHeight = (height * scaleFactor).toInt().coerceAtLeast(1)

        Log.d(TAG, "Scaling: ${width}x${height} → ${newWidth}x${newHeight} "
                + "(factor: ${"%.2f".format(scaleFactor)})")

        return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
    }

    /**
     * Compresses a bitmap to JPEG format.
     *
     * @param bitmap The bitmap to compress.
     * @param quality JPEG quality (1-100).
     * @return The compressed JPEG bytes, or null if compression fails.
     */
    private fun compressBitmap(bitmap: Bitmap, quality: Int): ByteArray? {
        return try {
            val stream = ByteArrayOutputStream()
            val success = bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)

            if (!success) {
                Log.e(TAG, "Bitmap.compress returned false")
                return null
            }

            val bytes = stream.toByteArray()
            stream.close()

            bytes
        } catch (e: Exception) {
            Log.e(TAG, "Compression failed", e)
            null
        }
    }
}