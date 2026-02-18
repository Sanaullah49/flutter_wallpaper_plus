package com.flutterwallpaperplus

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Utility for checking Android permissions across API levels.
 *
 * IMPORTANT: This helper only CHECKS permissions — it does NOT request them.
 * Permission requests must be handled by the host Flutter app using a
 * package like `permission_handler`.
 *
 * Permission model by API level:
 *
 * | API | Permission                    | Notes                       |
 * |-----|-------------------------------|-----------------------------|
 * | 24  | READ_EXTERNAL_STORAGE         | For reading local files     |
 * | 24  | SET_WALLPAPER                 | Normal perm, auto-granted   |
 * | 29  | Scoped storage introduced     | App-specific dirs free      |
 * | 33  | READ_MEDIA_IMAGES             | Replaces READ_EXT_STORAGE   |
 * | 33  | READ_MEDIA_VIDEO              | Replaces READ_EXT_STORAGE   |
 */
object PermissionHelper {

    /**
     * Checks if SET_WALLPAPER permission is granted.
     *
     * This is a "normal" permission that is auto-granted at install time
     * on virtually all devices. We check it anyway for edge cases
     * (MDM-managed devices, custom ROMs).
     */
    fun hasWallpaperPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.SET_WALLPAPER
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Checks if the app can read external files.
     *
     * Only relevant for WallpaperSource.file() with paths outside
     * the app's own directories. Assets and URLs don't need this.
     *
     * API 33+: Uses granular READ_MEDIA_* permissions.
     * API 29-32: Uses READ_EXTERNAL_STORAGE (scoped storage may limit scope).
     * API 24-28: Uses READ_EXTERNAL_STORAGE (full access).
     */
    fun hasStorageReadPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+: Check granular media permissions
            val hasImagePerm = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_MEDIA_IMAGES
            ) == PackageManager.PERMISSION_GRANTED

            val hasVideoPerm = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_MEDIA_VIDEO
            ) == PackageManager.PERMISSION_GRANTED

            hasImagePerm || hasVideoPerm
        } else {
            // Android 7-12: Check legacy storage permission
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    /**
     * Checks if the device supports live wallpapers.
     *
     * Some low-end devices, Android Go editions, or custom firmware
     * may not support this feature.
     */
    fun supportsLiveWallpaper(context: Context): Boolean {
        return context.packageManager.hasSystemFeature(
            PackageManager.FEATURE_LIVE_WALLPAPER
        )
    }

    /**
     * Checks if WallpaperManager reports wallpaper as supported.
     *
     * This can return false on some managed/kiosk devices.
     */
    fun isWallpaperSupported(context: Context): Boolean {
        return try {
            val wm = android.app.WallpaperManager.getInstance(context)
            wm.isWallpaperSupported
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Checks if the device/policy allows setting wallpaper.
     *
     * Returns false if an MDM policy or manufacturer restriction
     * blocks wallpaper changes.
     *
     * Only available on API 24+.
     */
    fun isSetWallpaperAllowed(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val wm = android.app.WallpaperManager.getInstance(context)
                wm.isSetWallpaperAllowed
            } else {
                true // No way to check on older APIs, assume allowed
            }
        } catch (e: Exception) {
            true // Assume allowed if check fails
        }
    }
}