/// Structured error codes for precise programmatic error handling.
///
/// Every [WallpaperResult] includes an error code so callers can
/// branch on specific failure modes rather than parsing message strings.
///
/// ```dart
/// final result = await FlutterWallpaperPlus.setImageWallpaper(...);
/// if (result.errorCode == WallpaperErrorCode.downloadFailed) {
///   // Show retry UI
/// }
/// ```
enum WallpaperErrorCode {
  /// No error — the operation succeeded.
  none,

  /// The source asset, file, or URL could not be found or read.
  sourceNotFound,

  /// Network error while downloading from a URL.
  ///
  /// This covers DNS failures, timeouts, HTTP errors, and
  /// interrupted downloads.
  downloadFailed,

  /// The requested feature is not supported on this device or
  /// Android version.
  ///
  /// For example: live wallpapers on a device without
  /// [PackageManager.FEATURE_LIVE_WALLPAPER].
  unsupported,

  /// A required runtime permission was denied by the user.
  permissionDenied,

  /// The WallpaperManager failed to apply the wallpaper.
  ///
  /// This can happen due to corrupt images, unsupported formats,
  /// or internal system errors.
  applyFailed,

  /// Video decoding, playback, or rendering error.
  videoError,

  /// Thumbnail extraction failed.
  ///
  /// The video may be corrupt, use an unsupported codec, or
  /// have no video track.
  thumbnailFailed,

  /// Cache read/write/clear operation failed.
  cacheFailed,

  /// A device manufacturer restriction prevents the operation.
  ///
  /// Some OEMs (Samsung, Xiaomi, Huawei) impose additional
  /// restrictions on wallpaper setting that go beyond stock Android.
  manufacturerRestriction,

  /// An unknown or unexpected error occurred.
  ///
  /// Check the [WallpaperResult.message] for details.
  unknown,
}

/// Extension to safely parse error code strings from the platform layer.
extension WallpaperErrorCodeParsing on WallpaperErrorCode {
  /// Converts a string received from the platform channel into
  /// a [WallpaperErrorCode] enum value.
  ///
  /// Returns [WallpaperErrorCode.unknown] if the string doesn't
  /// match any known code, and [WallpaperErrorCode.none] if the
  /// string is null.
  static WallpaperErrorCode fromString(String? value) {
    if (value == null || value.isEmpty) {
      return WallpaperErrorCode.none;
    }
    return WallpaperErrorCode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => WallpaperErrorCode.unknown,
    );
  }
}
