package com.flutterwallpaperplus

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

/**
 * Thread-safe LRU cache manager for wallpaper media files and thumbnails.
 *
 * Features:
 * - SHA-256 filename hashing for unique, collision-resistant file names
 * - LRU eviction when total cache size exceeds configurable limit
 * - Separate directories for media files and thumbnails
 * - Atomic file writes (write to .tmp, then rename) to prevent corruption
 * - OkHttp for reliable HTTP downloads with timeouts and redirect following
 * - Coroutine-safe with Mutex for cache eviction
 *
 * Directory structure:
 * ```
 * <app-cache-dir>/
 * ├── wallpaper_plus_cache/   # Downloaded/extracted media files
 * │   ├── a1b2c3d4...jpg
 * │   ├── e5f6g7h8...mp4
 * │   └── ...
 * └── wallpaper_plus_thumbs/  # Generated thumbnails
 *     ├── i9j0k1l2...jpg
 *     └── ...
 * ```
 */
class CacheManager(private val context: Context) {

    companion object {
        private const val TAG = "CacheManager"
        private const val CACHE_DIR_NAME = "wallpaper_plus_cache"
        private const val THUMB_DIR_NAME = "wallpaper_plus_thumbs"
        private const val DEFAULT_MAX_CACHE_BYTES = 200L * 1024 * 1024 // 200 MB
        private const val CONNECT_TIMEOUT_SECONDS = 30L
        private const val READ_TIMEOUT_SECONDS = 120L
        private const val HASH_TRUNCATE_LENGTH = 32
        private const val DOWNLOAD_BUFFER_SIZE = 8192
    }

    /**
     * Mutex for thread-safe cache eviction.
     * Only eviction needs synchronization — reads and individual
     * writes are safe on their own files.
     */
    private val evictionMutex = Mutex()

    /**
     * Maximum total cache size in bytes.
     * Can be changed at runtime via [setMaxCacheSize].
     * Volatile for visibility across coroutines.
     */
    @Volatile
    var maxCacheSize: Long = DEFAULT_MAX_CACHE_BYTES

    /**
     * OkHttp client, lazily initialized.
     * Shared across all downloads for connection pooling.
     */
    private val httpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(CONNECT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .readTimeout(READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .followRedirects(true)
            .followSslRedirects(true)
            .retryOnConnectionFailure(true)
            .build()
    }

    /**
     * Media cache directory — created lazily on first access.
     */
    private val cacheDir: File
        get() = File(context.cacheDir, CACHE_DIR_NAME).also {
            if (!it.exists()) it.mkdirs()
        }

    /**
     * Thumbnail cache directory — created lazily on first access.
     */
    private val thumbDir: File
        get() = File(context.cacheDir, THUMB_DIR_NAME).also {
            if (!it.exists()) it.mkdirs()
        }

    // ================================================================
    // Public API
    // ================================================================

    /**
     * Returns a cached file for the given URL, downloading if not cached.
     *
     * If the file is already cached and non-empty, it is returned
     * immediately with its last-modified time updated (LRU touch).
     *
     * If not cached, the file is downloaded to a temporary file first,
     * then atomically renamed to prevent serving partial downloads.
     *
     * @param url The remote URL to download from.
     * @return The local cached [File].
     * @throws DownloadException if the download fails.
     */
    suspend fun getOrDownload(url: String): File = withContext(Dispatchers.IO) {
        val hash = hashKey(url)
        val extension = extractExtension(url)
        val cachedFile = File(cacheDir, "$hash$extension")

        // Cache hit — touch for LRU and return
        if (cachedFile.exists() && cachedFile.length() > 0) {
            Log.d(TAG, "Cache hit: ${cachedFile.name}")
            cachedFile.setLastModified(System.currentTimeMillis())
            return@withContext cachedFile
        }

        Log.d(TAG, "Cache miss, downloading: $url")

        // Download to temp file for atomic write
        val tempFile = File(cacheDir, "$hash.tmp")

        try {
            downloadToFile(url, tempFile)

            // Atomic rename
            if (!tempFile.renameTo(cachedFile)) {
                // renameTo can fail across filesystems — fallback to copy
                tempFile.copyTo(cachedFile, overwrite = true)
                tempFile.delete()
            }

            Log.d(TAG, "Downloaded and cached: ${cachedFile.name} " +
                    "(${cachedFile.length()} bytes)")

            // Enforce cache limit after adding new file
            enforceCacheLimit()

            cachedFile
        } catch (e: Exception) {
            // Clean up temp file on any failure
            tempFile.delete()
            throw e
        }
    }

    /**
     * Copies Flutter asset data into the cache directory.
     *
     * Assets are identified by their path and only written once.
     * Subsequent calls return the existing cached file.
     *
     * @param assetPath The Flutter asset path (used as cache key).
     * @param assetData The raw bytes of the asset.
     * @return The local cached [File].
     */
    suspend fun cacheAsset(
        assetPath: String,
        assetData: ByteArray
    ): File = withContext(Dispatchers.IO) {
        val hash = hashKey(assetPath)
        val extension = extractExtension(assetPath)
        val cachedFile = File(cacheDir, "$hash$extension")

        if (cachedFile.exists() && cachedFile.length() > 0) {
            Log.d(TAG, "Asset already cached: ${cachedFile.name}")
            cachedFile.setLastModified(System.currentTimeMillis())
            return@withContext cachedFile
        }

        cachedFile.writeBytes(assetData)
        Log.d(TAG, "Asset cached: ${cachedFile.name} (${assetData.size} bytes)")

        enforceCacheLimit()
        cachedFile
    }

    /**
     * Saves thumbnail bytes to the thumbnail cache.
     *
     * @param key Unique identifier for this thumbnail (typically the source path).
     * @param bytes The compressed JPEG thumbnail bytes.
     * @return The cached thumbnail [File].
     */
    suspend fun saveThumbnail(key: String, bytes: ByteArray): File =
        withContext(Dispatchers.IO) {
            val hash = hashKey(key)
            val file = File(thumbDir, "$hash.jpg")
            file.writeBytes(bytes)
            Log.d(TAG, "Thumbnail saved: ${file.name} (${bytes.size} bytes)")
            file
        }

    /**
     * Retrieves a cached thumbnail by key.
     *
     * @param key The same key used in [saveThumbnail].
     * @return The thumbnail bytes, or null if not cached.
     */
    suspend fun getThumbnail(key: String): ByteArray? =
        withContext(Dispatchers.IO) {
            val hash = hashKey(key)
            val file = File(thumbDir, "$hash.jpg")
            if (file.exists() && file.length() > 0) {
                Log.d(TAG, "Thumbnail cache hit: ${file.name}")
                file.readBytes()
            } else {
                null
            }
        }

    /**
     * Deletes all cached media files and thumbnails.
     *
     * @return true if all files were successfully deleted.
     */
    suspend fun clearAll(): Boolean = evictionMutex.withLock {
        withContext(Dispatchers.IO) {
            var allDeleted = true

            cacheDir.listFiles()?.forEach { file ->
                if (!file.delete()) {
                    Log.w(TAG, "Could not delete: ${file.name}")
                    allDeleted = false
                }
            }

            thumbDir.listFiles()?.forEach { file ->
                if (!file.delete()) {
                    Log.w(TAG, "Could not delete thumbnail: ${file.name}")
                    allDeleted = false
                }
            }

            val status = if (allDeleted) "completely" else "partially"
            Log.d(TAG, "Cache cleared $status")

            allDeleted
        }
    }

    /**
     * Calculates total size of all cached files.
     *
     * @return Total bytes used by media cache + thumbnail cache.
     */
    suspend fun totalSize(): Long = withContext(Dispatchers.IO) {
        val mediaSize = cacheDir.listFiles()
            ?.filter { !it.name.endsWith(".tmp") }
            ?.sumOf { it.length() }
            ?: 0L

        val thumbSize = thumbDir.listFiles()
            ?.sumOf { it.length() }
            ?: 0L

        mediaSize + thumbSize
    }

    // ================================================================
    // Private Helpers
    // ================================================================

    /**
     * Downloads a URL to a local file using OkHttp.
     *
     * @throws DownloadException on any HTTP or IO error.
     */
    private fun downloadToFile(url: String, targetFile: File) {
        val request = Request.Builder()
            .url(url)
            .header("User-Agent", "FlutterWallpaperPlus/1.0")
            .build()

        try {
            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    throw DownloadException(
                        "HTTP ${response.code}: ${response.message}",
                        response.code
                    )
                }

                val body = response.body
                    ?: throw DownloadException("Empty response body", -1)

                FileOutputStream(targetFile).use { output ->
                    body.byteStream().use { input ->
                        val buffer = ByteArray(DOWNLOAD_BUFFER_SIZE)
                        var bytesRead: Int
                        while (input.read(buffer).also { bytesRead = it } != -1) {
                            output.write(buffer, 0, bytesRead)
                        }
                        output.flush()
                    }
                }
            }
        } catch (e: DownloadException) {
            throw e // Re-throw our own exceptions as-is
        } catch (e: java.net.UnknownHostException) {
            throw DownloadException("DNS resolution failed: ${e.message}", -1)
        } catch (e: java.net.SocketTimeoutException) {
            throw DownloadException("Connection timed out: ${e.message}", -1)
        } catch (e: java.io.IOException) {
            throw DownloadException("IO error: ${e.message}", -1)
        } catch (e: Exception) {
            throw DownloadException("Download failed: ${e.message}", -1)
        }
    }

    /**
     * Enforces the maximum cache size by evicting oldest files (LRU).
     *
     * Files are sorted by last-modified time. The oldest files are
     * deleted first until total size is within the limit.
     *
     * Temporary (.tmp) files are always deleted first regardless of age.
     */
    private suspend fun enforceCacheLimit() = evictionMutex.withLock {
        withContext(Dispatchers.IO) {
            // First, clean up any orphaned temp files
            cacheDir.listFiles()
                ?.filter { it.name.endsWith(".tmp") }
                ?.forEach { it.delete() }

            // Calculate current total size
            val allFiles = mutableListOf<File>()
            cacheDir.listFiles()?.let { allFiles.addAll(it) }
            thumbDir.listFiles()?.let { allFiles.addAll(it) }

            var currentSize = allFiles.sumOf { it.length() }

            if (currentSize <= maxCacheSize) return@withContext

            Log.d(TAG, "Cache size ($currentSize) exceeds limit " +
                    "($maxCacheSize), evicting...")

            // Sort by last modified ascending (oldest first = evict first)
            val sorted = allFiles.sortedBy { it.lastModified() }

            var evictedCount = 0

            for (file in sorted) {
                if (currentSize <= maxCacheSize) break

                val fileSize = file.length()
                if (file.delete()) {
                    currentSize -= fileSize
                    evictedCount++
                }
            }

            Log.d(TAG, "Evicted $evictedCount files, " +
                    "new cache size: $currentSize bytes")
        }
    }

    /**
     * Generates a SHA-256 hash of the input string, truncated
     * to [HASH_TRUNCATE_LENGTH] hex characters.
     *
     * This provides:
     * - Deterministic file names for the same input
     * - No illegal filename characters
     * - Extremely low collision probability at 32 hex chars (128 bits)
     */
    private fun hashKey(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
            .take(HASH_TRUNCATE_LENGTH)
    }

    /**
     * Extracts and validates a file extension from a path or URL.
     *
     * Strips query parameters and fragments before extracting.
     * Only allows known-safe media extensions to prevent security issues.
     *
     * @return The extension including the dot (e.g., ".jpg"), or empty
     *   string if the extension is unknown or unsafe.
     */
    private fun extractExtension(path: String): String {
        // Remove query params and fragments
        val cleanPath = path
            .substringBefore('?')
            .substringBefore('#')

        val lastDot = cleanPath.lastIndexOf('.')
        if (lastDot < 0 || lastDot == cleanPath.lastIndex) return ""

        val ext = cleanPath.substring(lastDot).lowercase()

        // Allowlist of safe media extensions
        return when (ext) {
            ".jpg", ".jpeg", ".png", ".webp", ".bmp",   // Images
            ".gif",                                        // Animated
            ".mp4", ".webm", ".mkv", ".3gp", ".mov",    // Video
                -> ext
            else -> ""
        }
    }

    // ================================================================
    // Exceptions
    // ================================================================

    /**
     * Exception thrown when a URL download fails.
     *
     * @property httpCode The HTTP status code, or -1 for non-HTTP errors.
     */
    class DownloadException(
        message: String,
        val httpCode: Int
    ) : Exception(message)
}