/// Specifies which screen(s) to apply the wallpaper to.
///
/// On Android 7.0 (API 24)+, the system supports setting home screen
/// and lock screen wallpapers independently. On older versions,
/// [both] is always used regardless of the value passed.
///
/// Note: Some device manufacturers may not support separate lock screen
/// wallpapers. The plugin handles this gracefully and returns an
/// appropriate error code.
enum WallpaperTarget {
  /// Apply wallpaper to the home screen only.
  ///
  /// Maps to [WallpaperManager.FLAG_SYSTEM].
  home,

  /// Apply wallpaper to the lock screen only.
  ///
  /// Maps to [WallpaperManager.FLAG_LOCK].
  ///
  /// Not all devices support this independently.
  /// For live video wallpapers, lock-only is unsupported on Android
  /// public APIs.
  /// Some OEMs may also block image lock target for third-party apps.
  lock,

  /// Apply wallpaper to both home and lock screens.
  ///
  /// Maps to [WallpaperManager.FLAG_SYSTEM | WallpaperManager.FLAG_LOCK].
  /// On restrictive OEM ROMs, this target may be disabled at runtime.
  both,
}
