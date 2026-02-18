package com.flutterwallpaperplus

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Resolves wallpaper sources (asset, file, URL) into local files.
 *
 * This is the single choke point where all source types are normalized
 * into a local file path that downstream components can use uniformly.
 *
 * Resolution strategies:
 * - **Asset**: Reads from Flutter's asset bundle via Android AssetManager,
 *   then writes to cache (because AssetManager only provides InputStreams,
 *   and WallpaperManager/ExoPlayer need file paths).
 * - **File**: Validates existence and readability, returns as-is.
 * - **URL**: Downloads via CacheManager (which handles caching).
 *
 * All methods run on Dispatchers.IO and throw typed exceptions
 * that the caller can map to appropriate error codes.
 */
class SourceResolver(
    private val context: Context,
    private val cacheManager: CacheManager,
    private val flutterAssets: FlutterPlugin.FlutterAssets,
) {

    companion object {
        private const val TAG = "SourceResolver"
    }

    /**
     * Resolves any source type to a local file.
     *
     * @param sourceType One of "asset", "file", "url".
     * @param sourcePath The asset path, file path, or URL.
     * @return A local [File] that exists and is readable.
     * @throws SourceNotFoundException if the source cannot be found/accessed.
     * @throws CacheManager.DownloadException if a URL download fails.
     */
    suspend fun resolve(sourceType: String, sourcePath: String): File {
        Log.d(TAG, "Resolving source: type=$sourceType, path=$sourcePath")

        return when (sourceType) {
            "asset" -> resolveAsset(sourcePath)
            "file" -> resolveFile(sourcePath)
            "url" -> resolveUrl(sourcePath)
            else -> throw SourceNotFoundException(
                "Unknown source type: '$sourceType'. " +
                        "Expected 'asset', 'file', or 'url'."
            )
        }
    }

    /**
     * Resolves a Flutter asset to a local cached file.
     *
     * Flutter assets are stored inside the APK and accessed via
     * Android's AssetManager. Since most consumers (WallpaperManager,
     * ExoPlayer) need a file path, we extract the asset to the cache.
     *
     * The FlutterPlugin.FlutterAssets.getAssetFilePathByName() method
     * transforms the user-facing asset path (e.g., "assets/bg.jpg")
     * into the actual path inside the APK (e.g., "flutter_assets/assets/bg.jpg").
     */
    private suspend fun resolveAsset(assetPath: String): File =
        withContext(Dispatchers.IO) {
            try {
                // Transform Flutter asset path to APK-internal path
                val key = flutterAssets.getAssetFilePathByName(assetPath)
                Log.d(TAG, "Asset key resolved: $assetPath -> $key")

                // Read asset bytes via AssetManager
                val bytes = context.assets.open(key).use { inputStream ->
                    inputStream.readBytes()
                }

                if (bytes.isEmpty()) {
                    throw SourceNotFoundException(
                        "Asset '$assetPath' is empty (0 bytes)"
                    )
                }

                // Cache the extracted asset
                val file = cacheManager.cacheAsset(assetPath, bytes)

                Log.d(TAG, "Asset resolved to: ${file.absolutePath}")
                file
            } catch (e: SourceNotFoundException) {
                throw e // Re-throw our own exceptions
            } catch (e: java.io.FileNotFoundException) {
                throw SourceNotFoundException(
                    "Asset not found: '$assetPath'. " +
                            "Make sure it is listed in your pubspec.yaml assets section.",
                    e
                )
            } catch (e: Exception) {
                throw SourceNotFoundException(
                    "Failed to read asset '$assetPath': ${e.message}",
                    e
                )
            }
        }

    /**
     * Validates and returns a local file.
     *
     * Performs existence and readability checks before returning.
     */
    private suspend fun resolveFile(filePath: String): File =
        withContext(Dispatchers.IO) {
            val file = File(filePath)

            if (!file.exists()) {
                throw SourceNotFoundException(
                    "File not found: '$filePath'. " +
                            "The file may have been moved, deleted, or the path is incorrect."
                )
            }

            if (!file.isFile) {
                throw SourceNotFoundException(
                    "Path is not a file: '$filePath'. " +
                            "It may be a directory."
                )
            }

            if (!file.canRead()) {
                throw SourceNotFoundException(
                    "Cannot read file: '$filePath'. " +
                            "Check file permissions. On Android 10+, you may need to use " +
                            "files within your app's directory or request proper permissions."
                )
            }

            if (file.length() == 0L) {
                throw SourceNotFoundException(
                    "File is empty (0 bytes): '$filePath'"
                )
            }

            Log.d(TAG, "File resolved: ${file.absolutePath} " +
                    "(${file.length()} bytes)")
            file
        }

    /**
     * Downloads (or retrieves from cache) a URL.
     *
     * Delegates entirely to CacheManager, which handles caching.
     */
    private suspend fun resolveUrl(url: String): File {
        return try {
            val file = cacheManager.getOrDownload(url)
            Log.d(TAG, "URL resolved to: ${file.absolutePath}")
            file
        } catch (e: CacheManager.DownloadException) {
            throw e // Let the caller handle download errors separately
        } catch (e: Exception) {
            throw SourceNotFoundException(
                "Failed to download from URL '$url': ${e.message}",
                e
            )
        }
    }

    // ================================================================
    // Exceptions
    // ================================================================

    /**
     * Thrown when a wallpaper source cannot be found, accessed, or read.
     */
    class SourceNotFoundException(
        message: String,
        cause: Throwable? = null
    ) : Exception(message, cause)
}