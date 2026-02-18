/// Flutter Wallpaper Plus — Production-grade wallpaper plugin for Android.
///
/// Set image and video (live) wallpapers from assets, files, and URLs
/// with intelligent caching, thumbnail generation, toast customization,
/// and structured error handling.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_wallpaper_plus/flutter_wallpaper_plus.dart';
///
/// // Set image wallpaper from URL
/// final result = await FlutterWallpaperPlus.setImageWallpaper(
///   source: WallpaperSource.url('https://example.com/bg.jpg'),
///   target: WallpaperTarget.both,
/// );
///
/// if (result.success) {
///   print('Done!');
/// } else {
///   print('Error: ${result.errorCode}');
/// }
/// ```
///
/// ## Video Wallpaper
///
/// ```dart
/// final result = await FlutterWallpaperPlus.setVideoWallpaper(
///   source: WallpaperSource.asset('assets/live_bg.mp4'),
///   target: WallpaperTarget.home,
///   enableAudio: false,
///   loop: true,
/// );
/// ```
///
/// ## Thumbnail Generation
///
/// ```dart
/// final thumbnail = await FlutterWallpaperPlus.getVideoThumbnail(
///   source: WallpaperSource.url('https://example.com/video.mp4'),
///   quality: 50,
/// );
///
/// if (thumbnail != null) {
///   Image.memory(thumbnail);
/// }
/// ```
library;

import 'dart:typed_data';

import 'src/flutter_wallpaper_plus_impl.dart';
import 'src/target_support_policy.dart';
import 'src/wallpaper_result.dart';
import 'src/wallpaper_source.dart';
import 'src/wallpaper_target.dart';

// Re-export all public types so users only need one import
export 'src/wallpaper_error_code.dart';
export 'src/wallpaper_result.dart';
export 'src/wallpaper_source.dart';
export 'src/target_support_policy.dart';
export 'src/wallpaper_target.dart';

/// Primary API for setting wallpapers on Android.
///
/// All methods are static. This class cannot be instantiated.
///
/// Every method that performs a wallpaper operation returns a
/// [WallpaperResult] with structured success/error information.
/// Methods never throw exceptions for operational failures.
///
/// Input validation errors (empty paths, invalid URLs) throw
/// [ArgumentError] at the [WallpaperSource] construction site,
/// before any platform call is made.
class FlutterWallpaperPlus {
  // Prevent instantiation and subclassing
  FlutterWallpaperPlus._();

  /// Sets a static image as the device wallpaper.
  ///
  /// ### Parameters
  ///
  /// - [source] — Where the image comes from (asset, file, or URL).
  ///   URLs are downloaded and cached automatically.
  ///
  /// - [target] — Which screen(s) to apply the wallpaper to.
  ///   On pre-API 24 devices, this is ignored and both screens are set.
  ///   On some OEM ROMs, lock/both can be blocked and return
  ///   `WallpaperErrorCode.manufacturerRestriction`.
  ///
  /// - [successMessage] — Custom message shown in the Android Toast
  ///   and returned in [WallpaperResult.message] on success.
  ///   Default: `"Wallpaper set successfully"`.
  ///
  /// - [errorMessage] — Custom fallback message for the Toast on failure.
  ///   The actual error description is always available in the result.
  ///   Default: `"Failed to set wallpaper"`.
  ///
  /// - [showToast] — Whether to show an Android Toast notification.
  ///   Set to `false` if you want to handle UI feedback yourself.
  ///   Default: `true`.
  ///
  /// ### Returns
  ///
  /// A [WallpaperResult] with:
  /// - [WallpaperResult.success] — `true` if the wallpaper was applied.
  /// - [WallpaperResult.message] — Description of the outcome.
  /// - [WallpaperResult.errorCode] — Structured error code for failures.
  ///
  /// ### Example
  ///
  /// ```dart
  /// final result = await FlutterWallpaperPlus.setImageWallpaper(
  ///   source: WallpaperSource.url('https://example.com/nature.jpg'),
  ///   target: WallpaperTarget.home,
  ///   successMessage: 'Nature wallpaper applied!',
  ///   showToast: true,
  /// );
  /// ```
  static Future<WallpaperResult> setImageWallpaper({
    required WallpaperSource source,
    required WallpaperTarget target,
    String? successMessage,
    String? errorMessage,
    bool showToast = true,
  }) {
    return FlutterWallpaperPlusImpl.setImageWallpaper(
      source: source,
      target: target,
      successMessage: successMessage,
      errorMessage: errorMessage,
      showToast: showToast,
    );
  }

  /// Sets a video as a live wallpaper using Android's WallpaperService.
  ///
  /// This launches the system's live wallpaper chooser. The user must
  /// confirm the selection. The video plays using Media3 ExoPlayer
  /// inside a [WallpaperService], which means:
  ///
  /// - It survives app kill (the service runs independently)
  /// - It handles screen rotation without crashing
  /// - It pauses when not visible to save battery
  /// - It resumes seamlessly when the home screen is shown
  ///
  /// ### Parameters
  ///
  /// - [source] — Where the video comes from (asset, file, or URL).
  ///
  /// - [target] — Which screen to apply to.
  ///   `WallpaperTarget.lock` is not supported for live wallpapers on
  ///   Android public APIs and returns `WallpaperErrorCode.unsupported`.
  ///   `WallpaperTarget.home` and `WallpaperTarget.both` are best-effort
  ///   requests and still use the system picker, which decides final behavior.
  ///
  /// - [enableAudio] — Whether to play the video's audio track.
  ///   Default: `false` (silent).
  ///
  /// - [loop] — Whether to loop the video seamlessly.
  ///   Default: `true`.
  ///
  /// - [successMessage] / [errorMessage] / [showToast] — Same as
  ///   [setImageWallpaper].
  ///
  /// ### Example
  ///
  /// ```dart
  /// final result = await FlutterWallpaperPlus.setVideoWallpaper(
  ///   source: WallpaperSource.asset('assets/rain.mp4'),
  ///   target: WallpaperTarget.home,
  ///   enableAudio: false,
  ///   loop: true,
  /// );
  /// ```
  static Future<WallpaperResult> setVideoWallpaper({
    required WallpaperSource source,
    required WallpaperTarget target,
    bool enableAudio = false,
    bool loop = true,
    String? successMessage,
    String? errorMessage,
    bool showToast = true,
  }) {
    return FlutterWallpaperPlusImpl.setVideoWallpaper(
      source: source,
      target: target,
      enableAudio: enableAudio,
      loop: loop,
      successMessage: successMessage,
      errorMessage: errorMessage,
      showToast: showToast,
    );
  }

  /// Extracts a thumbnail frame from a video source.
  ///
  /// Returns compressed JPEG bytes as [Uint8List], or `null` if
  /// thumbnail generation fails.
  ///
  /// The thumbnail is extracted from approximately 1 second into the
  /// video, scaled down to a maximum dimension of 480px, and
  /// compressed at the specified [quality].
  ///
  /// ### Parameters
  ///
  /// - [source] — The video source (asset, file, or URL).
  ///
  /// - [quality] — JPEG compression quality from 1 (smallest file,
  ///   worst quality) to 100 (largest file, best quality).
  ///   Default: `30` (good for preview thumbnails).
  ///
  /// - [cache] — Whether to cache the generated thumbnail so
  ///   subsequent calls return instantly.
  ///   Default: `true`.
  ///
  /// ### Example
  ///
  /// ```dart
  /// final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
  ///   source: WallpaperSource.url('https://example.com/video.mp4'),
  ///   quality: 50,
  /// );
  ///
  /// if (bytes != null) {
  ///   setState(() => _thumbnailBytes = bytes);
  ///   // In build: Image.memory(_thumbnailBytes!)
  /// }
  /// ```
  static Future<Uint8List?> getVideoThumbnail({
    required WallpaperSource source,
    int quality = 30,
    bool cache = true,
  }) {
    return FlutterWallpaperPlusImpl.getVideoThumbnail(
      source: source,
      quality: quality,
      cache: cache,
    );
  }

  /// Returns device policy for wallpaper target reliability/support.
  ///
  /// Use this to disable unsupported or unreliable target options in UI.
  static Future<TargetSupportPolicy> getTargetSupportPolicy() {
    return FlutterWallpaperPlusImpl.getTargetSupportPolicy();
  }

  /// Clears all cached media files and thumbnails.
  ///
  /// Returns a [WallpaperResult] indicating whether the cache was
  /// successfully cleared.
  ///
  /// ```dart
  /// final result = await FlutterWallpaperPlus.clearCache();
  /// print(result.success ? 'Cleared!' : 'Failed: ${result.message}');
  /// ```
  static Future<WallpaperResult> clearCache() {
    return FlutterWallpaperPlusImpl.clearCache();
  }

  /// Returns the total size of all cached files in bytes.
  ///
  /// Returns 0 if the cache is empty or if an error occurs.
  ///
  /// ```dart
  /// final bytes = await FlutterWallpaperPlus.getCacheSize();
  /// final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
  /// print('Cache: $mb MB');
  /// ```
  static Future<int> getCacheSize() {
    return FlutterWallpaperPlusImpl.getCacheSize();
  }

  /// Configures the maximum cache size in bytes.
  ///
  /// When the total cached data exceeds this limit, the oldest files
  /// (least recently used) are automatically evicted during the next
  /// cache write operation.
  ///
  /// Default limit: 200 MB (209715200 bytes).
  ///
  /// Throws [ArgumentError] if [maxBytes] is not positive.
  ///
  /// ```dart
  /// // Set cache limit to 100 MB
  /// await FlutterWallpaperPlus.setMaxCacheSize(100 * 1024 * 1024);
  /// ```
  static Future<void> setMaxCacheSize(int maxBytes) {
    return FlutterWallpaperPlusImpl.setMaxCacheSize(maxBytes);
  }
}
