import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wallpaper_plus/flutter_wallpaper_plus.dart';
import 'package:integration_test/integration_test.dart';

/// Integration tests run on a real Android device/emulator.
///
/// These tests verify that the MethodChannel communication works
/// end-to-end, but they do NOT actually set wallpapers (that would
/// require user interaction with the system picker).
///
/// Run with:
/// ```bash
/// cd example
/// flutter test integration_test/plugin_integration_test.dart
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Plugin integration', () {
    testWidgets('getCacheSize returns a non-negative value', (
      WidgetTester tester,
    ) async {
      final size = await FlutterWallpaperPlus.getCacheSize();
      expect(size, greaterThanOrEqualTo(0));
    });

    testWidgets('clearCache returns success', (WidgetTester tester) async {
      final result = await FlutterWallpaperPlus.clearCache();
      expect(result.success, isTrue);
    });

    testWidgets('setMaxCacheSize does not throw', (WidgetTester tester) async {
      await FlutterWallpaperPlus.setMaxCacheSize(100 * 1024 * 1024);
      // No exception = pass
    });

    testWidgets('getCacheSize after clear is 0', (WidgetTester tester) async {
      await FlutterWallpaperPlus.clearCache();
      final size = await FlutterWallpaperPlus.getCacheSize();
      expect(size, equals(0));
    });

    testWidgets('setImageWallpaper with bad URL returns download error', (
      WidgetTester tester,
    ) async {
      final result = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://invalid.test.example/nope.jpg'),
        target: WallpaperTarget.home,
        showToast: false,
      );

      expect(result.success, isFalse);
      expect(
        result.errorCode,
        anyOf(
          WallpaperErrorCode.downloadFailed,
          WallpaperErrorCode.sourceNotFound,
        ),
      );
    });

    testWidgets('setImageWallpaper with bad asset returns source error', (
      WidgetTester tester,
    ) async {
      final result = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.asset('assets/nonexistent_file.jpg'),
        target: WallpaperTarget.home,
        showToast: false,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.sourceNotFound);
    });

    testWidgets('getVideoThumbnail with bad URL returns null', (
      WidgetTester tester,
    ) async {
      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://invalid.test.example/nope.mp4'),
        cache: false,
      );

      expect(bytes, isNull);
    });
  });
}
