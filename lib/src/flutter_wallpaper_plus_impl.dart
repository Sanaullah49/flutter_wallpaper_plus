import 'dart:async';

import 'package:flutter/services.dart';

import 'wallpaper_error_code.dart';
import 'wallpaper_result.dart';
import 'wallpaper_source.dart';
import 'wallpaper_target.dart';
import 'target_support_policy.dart';
import 'wallpaper_auto_change_status.dart';

/// Internal implementation layer that communicates with the Android platform.
///
/// This class is NOT exported — users interact with the public
/// [FlutterWallpaperPlus] facade instead.
///
/// Design rationale:
/// - Separating the platform channel logic from the public API allows
///   us to change the communication mechanism (e.g., switch to Pigeon)
///   without breaking the public interface.
/// - All PlatformException handling is centralized here.
/// - Every method returns a structured result, never throws.
class FlutterWallpaperPlusImpl {
  // Private constructor prevents instantiation
  FlutterWallpaperPlusImpl._();

  /// The single method channel shared across all plugin calls.
  ///
  /// Channel name follows reverse-domain convention for uniqueness.
  static const MethodChannel _channel = MethodChannel(
    'com.flutterwallpaperplus/methods',
  );

  /// Sets a static image as the device wallpaper.
  ///
  /// Resolves the source (downloading if URL, extracting if asset),
  /// then applies it to the specified target screen(s).
  static Future<WallpaperResult> setImageWallpaper({
    required WallpaperSource source,
    required WallpaperTarget target,
    String? successMessage,
    String? errorMessage,
    bool showToast = true,
    bool goToHome = false,
  }) async {
    try {
      final result = await _channel
          .invokeMethod<Map>('setImageWallpaper', <String, dynamic>{
            'source': source.toMap(),
            'target': target.name,
            'successMessage': successMessage ?? 'Wallpaper set successfully',
            'errorMessage': errorMessage ?? 'Failed to set wallpaper',
            'showToast': showToast,
            'goToHome': goToHome,
          });

      if (result != null) {
        return WallpaperResult.fromMap(result);
      }

      return WallpaperResult(
        success: false,
        message: errorMessage ?? 'No response from platform layer',
        errorCode: WallpaperErrorCode.unknown,
      );
    } on PlatformException catch (e) {
      return WallpaperResult(
        success: false,
        message: e.message ?? errorMessage ?? 'Platform error occurred',
        errorCode: WallpaperErrorCodeParsing.fromString(e.code),
      );
    } on MissingPluginException {
      return const WallpaperResult(
        success: false,
        message: 'Plugin not available. Are you running on Android?',
        errorCode: WallpaperErrorCode.unsupported,
      );
    } catch (e) {
      return WallpaperResult(
        success: false,
        message: 'Unexpected error: ${e.toString()}',
        errorCode: WallpaperErrorCode.unknown,
      );
    }
  }

  /// Sets a video as a live wallpaper using Android's WallpaperService.
  ///
  /// The video file is resolved and cached, then the live wallpaper
  /// chooser intent is launched. The user must confirm the selection.
  ///
  /// Configuration (audio, loop) is persisted in SharedPreferences
  /// so the service can read it after app kill.
  static Future<WallpaperResult> setVideoWallpaper({
    required WallpaperSource source,
    required WallpaperTarget target,
    bool enableAudio = false,
    bool loop = true,
    String? successMessage,
    String? errorMessage,
    bool showToast = true,
    bool goToHome = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map>(
        'setVideoWallpaper',
        <String, dynamic>{
          'source': source.toMap(),
          'target': target.name,
          'enableAudio': enableAudio,
          'loop': loop,
          'successMessage': successMessage ?? 'Live wallpaper set successfully',
          'errorMessage': errorMessage ?? 'Failed to set live wallpaper',
          'showToast': showToast,
          'goToHome': goToHome,
        },
      );

      if (result != null) {
        return WallpaperResult.fromMap(result);
      }

      return WallpaperResult(
        success: false,
        message: errorMessage ?? 'No response from platform layer',
        errorCode: WallpaperErrorCode.unknown,
      );
    } on PlatformException catch (e) {
      return WallpaperResult(
        success: false,
        message: e.message ?? errorMessage ?? 'Platform error occurred',
        errorCode: WallpaperErrorCodeParsing.fromString(e.code),
      );
    } on MissingPluginException {
      return const WallpaperResult(
        success: false,
        message: 'Plugin not available. Are you running on Android?',
        errorCode: WallpaperErrorCode.unsupported,
      );
    } catch (e) {
      return WallpaperResult(
        success: false,
        message: 'Unexpected error: ${e.toString()}',
        errorCode: WallpaperErrorCode.unknown,
      );
    }
  }

  /// Starts wallpaper Auto Change using a pre-resolved playlist and interval.
  static Future<WallpaperResult> startWallpaperAutoChange({
    required List<WallpaperSource> sources,
    required WallpaperTarget target,
    required Duration interval,
    String? successMessage,
    String? errorMessage,
    bool showToast = true,
    bool goToHome = false,
  }) async {
    if (sources.isEmpty) {
      throw ArgumentError.value(
        sources,
        'sources',
        'At least one wallpaper source is required',
      );
    }
    if (interval.inMinutes < 1) {
      throw ArgumentError.value(
        interval,
        'interval',
        'Auto Change requires a minimum interval of 1 minute',
      );
    }

    try {
      final result = await _channel
          .invokeMethod<Map>('startWallpaperAutoChange', <String, dynamic>{
            'sources': sources.map((source) => source.toMap()).toList(),
            'target': target.name,
            'intervalMinutes': interval.inMinutes,
            'successMessage': successMessage ?? 'Wallpaper Auto Change started',
            'errorMessage':
                errorMessage ?? 'Failed to start Wallpaper Auto Change',
            'showToast': showToast,
            'goToHome': goToHome,
          });

      if (result != null) {
        return WallpaperResult.fromMap(result);
      }

      return WallpaperResult(
        success: false,
        message: errorMessage ?? 'No response from platform layer',
        errorCode: WallpaperErrorCode.unknown,
      );
    } on PlatformException catch (e) {
      return WallpaperResult(
        success: false,
        message: e.message ?? errorMessage ?? 'Platform error occurred',
        errorCode: WallpaperErrorCodeParsing.fromString(e.code),
      );
    } on MissingPluginException {
      return const WallpaperResult(
        success: false,
        message: 'Plugin not available. Are you running on Android?',
        errorCode: WallpaperErrorCode.unsupported,
      );
    } catch (e) {
      return WallpaperResult(
        success: false,
        message: 'Unexpected error: ${e.toString()}',
        errorCode: WallpaperErrorCode.unknown,
      );
    }
  }

  /// Stops wallpaper Auto Change and clears the current playlist.
  static Future<WallpaperResult> stopWallpaperAutoChange({
    String? successMessage,
    String? errorMessage,
    bool showToast = true,
  }) async {
    try {
      final result = await _channel
          .invokeMethod<Map>('stopWallpaperAutoChange', <String, dynamic>{
            'successMessage': successMessage ?? 'Wallpaper Auto Change stopped',
            'errorMessage':
                errorMessage ?? 'Failed to stop Wallpaper Auto Change',
            'showToast': showToast,
          });

      if (result != null) {
        return WallpaperResult.fromMap(result);
      }

      return WallpaperResult(
        success: false,
        message: errorMessage ?? 'No response from platform layer',
        errorCode: WallpaperErrorCode.unknown,
      );
    } on PlatformException catch (e) {
      return WallpaperResult(
        success: false,
        message: e.message ?? errorMessage ?? 'Platform error occurred',
        errorCode: WallpaperErrorCodeParsing.fromString(e.code),
      );
    } on MissingPluginException {
      return const WallpaperResult(
        success: false,
        message: 'Plugin not available. Are you running on Android?',
        errorCode: WallpaperErrorCode.unsupported,
      );
    } catch (e) {
      return WallpaperResult(
        success: false,
        message: 'Unexpected error: ${e.toString()}',
        errorCode: WallpaperErrorCode.unknown,
      );
    }
  }

  /// Returns the current wallpaper Auto Change status.
  static Future<WallpaperAutoChangeStatus>
  getWallpaperAutoChangeStatus() async {
    try {
      final result = await _channel.invokeMethod<Map>(
        'getWallpaperAutoChangeStatus',
      );
      return WallpaperAutoChangeStatus.fromMap(result);
    } on PlatformException {
      return const WallpaperAutoChangeStatus.stopped();
    } on MissingPluginException {
      return const WallpaperAutoChangeStatus.stopped();
    } catch (_) {
      return const WallpaperAutoChangeStatus.stopped();
    }
  }

  /// Applies the next wallpaper in the current Auto Change playlist immediately.
  static Future<WallpaperResult> applyNextWallpaperNow({
    String? successMessage,
    String? errorMessage,
    bool showToast = true,
    bool goToHome = false,
  }) async {
    try {
      final result = await _channel
          .invokeMethod<Map>('applyNextWallpaperNow', <String, dynamic>{
            'successMessage':
                successMessage ?? 'Applied next Auto Change wallpaper',
            'errorMessage':
                errorMessage ?? 'Failed to apply next Auto Change wallpaper',
            'showToast': showToast,
            'goToHome': goToHome,
          });

      if (result != null) {
        return WallpaperResult.fromMap(result);
      }

      return WallpaperResult(
        success: false,
        message: errorMessage ?? 'No response from platform layer',
        errorCode: WallpaperErrorCode.unknown,
      );
    } on PlatformException catch (e) {
      return WallpaperResult(
        success: false,
        message: e.message ?? errorMessage ?? 'Platform error occurred',
        errorCode: WallpaperErrorCodeParsing.fromString(e.code),
      );
    } on MissingPluginException {
      return const WallpaperResult(
        success: false,
        message: 'Plugin not available. Are you running on Android?',
        errorCode: WallpaperErrorCode.unsupported,
      );
    } catch (e) {
      return WallpaperResult(
        success: false,
        message: 'Unexpected error: ${e.toString()}',
        errorCode: WallpaperErrorCode.unknown,
      );
    }
  }

  /// Extracts a thumbnail frame from a video source.
  ///
  /// Returns compressed JPEG bytes as [Uint8List], or null if
  /// thumbnail generation fails for any reason.
  ///
  /// Thumbnails are optionally cached so repeated calls with the
  /// same source return instantly.
  static Future<Uint8List?> getVideoThumbnail({
    required WallpaperSource source,
    int quality = 30,
    bool cache = true,
    bool goToHome = false,
  }) async {
    try {
      final result = await _channel
          .invokeMethod<Uint8List>('getVideoThumbnail', <String, dynamic>{
            'source': source.toMap(),
            'quality': quality.clamp(1, 100),
            'cache': cache,
            'goToHome': goToHome,
          });
      return result;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Returns target support policy for the current Android device/ROM.
  static Future<TargetSupportPolicy> getTargetSupportPolicy({
    bool goToHome = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map>(
        'getTargetSupportPolicy',
        <String, dynamic>{'goToHome': goToHome},
      );
      return TargetSupportPolicy.fromMap(result);
    } on PlatformException {
      return TargetSupportPolicy.unknown;
    } on MissingPluginException {
      return TargetSupportPolicy.unknown;
    } catch (_) {
      return TargetSupportPolicy.unknown;
    }
  }

  /// Opens Android's native wallpaper chooser/settings screen.
  static Future<WallpaperResult> openNativeWallpaperChooser({
    required WallpaperSource source,
    String? successMessage,
    String? errorMessage,
    bool showToast = true,
    bool goToHome = false,
  }) async {
    try {
      final result = await _channel
          .invokeMethod<Map>('openNativeWallpaperChooser', <String, dynamic>{
            'source': source.toMap(),
            'successMessage': successMessage ?? 'Wallpaper chooser opened',
            'errorMessage': errorMessage ?? 'Failed to open wallpaper chooser',
            'showToast': showToast,
            'goToHome': goToHome,
          });

      if (result != null) {
        return WallpaperResult.fromMap(result);
      }

      return WallpaperResult(
        success: false,
        message: errorMessage ?? 'No response from platform layer',
        errorCode: WallpaperErrorCode.unknown,
      );
    } on PlatformException catch (e) {
      return WallpaperResult(
        success: false,
        message: e.message ?? errorMessage ?? 'Platform error occurred',
        errorCode: WallpaperErrorCodeParsing.fromString(e.code),
      );
    } on MissingPluginException {
      return const WallpaperResult(
        success: false,
        message: 'Plugin not available. Are you running on Android?',
        errorCode: WallpaperErrorCode.unsupported,
      );
    } catch (e) {
      return WallpaperResult(
        success: false,
        message: 'Unexpected error: ${e.toString()}',
        errorCode: WallpaperErrorCode.unknown,
      );
    }
  }

  /// Clears all cached media files and thumbnails.
  static Future<WallpaperResult> clearCache({bool goToHome = false}) async {
    try {
      final result = await _channel.invokeMethod<Map>(
        'clearCache',
        <String, dynamic>{'goToHome': goToHome},
      );

      if (result != null) {
        return WallpaperResult.fromMap(result);
      }

      return const WallpaperResult(success: true, message: 'Cache cleared');
    } on PlatformException catch (e) {
      return WallpaperResult(
        success: false,
        message: e.message ?? 'Failed to clear cache',
        errorCode: WallpaperErrorCode.cacheFailed,
      );
    } catch (e) {
      return WallpaperResult(
        success: false,
        message: 'Unexpected error: ${e.toString()}',
        errorCode: WallpaperErrorCode.cacheFailed,
      );
    }
  }

  /// Returns total size of all cached files in bytes.
  ///
  /// Returns 0 if cache is empty or if an error occurs.
  static Future<int> getCacheSize({bool goToHome = false}) async {
    try {
      final result = await _channel.invokeMethod<int>(
        'getCacheSize',
        <String, dynamic>{'goToHome': goToHome},
      );
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Configures the maximum cache size in bytes.
  ///
  /// When the cache exceeds this limit, the oldest files (LRU) are
  /// automatically evicted during the next cache write.
  ///
  /// Default is 200 MB.
  static Future<void> setMaxCacheSize(
    int maxBytes, {
    bool goToHome = false,
  }) async {
    if (maxBytes <= 0) {
      throw ArgumentError.value(
        maxBytes,
        'maxBytes',
        'Must be a positive integer',
      );
    }

    try {
      await _channel.invokeMethod<void>('setMaxCacheSize', <String, dynamic>{
        'maxBytes': maxBytes,
        'goToHome': goToHome,
      });
    } catch (_) {
      // Cache configuration is non-critical — fail silently.
      // The default 200 MB limit remains in effect.
    }
  }
}
