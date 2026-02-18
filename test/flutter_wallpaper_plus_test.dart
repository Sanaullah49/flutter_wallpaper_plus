import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wallpaper_plus/flutter_wallpaper_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.flutterwallpaperplus/methods');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          log.add(call);
          switch (call.method) {
            case 'setImageWallpaper':
              return <String, dynamic>{
                'success': true,
                'message': 'Wallpaper set',
                'errorCode': 'none',
              };
            case 'setVideoWallpaper':
              return <String, dynamic>{
                'success': true,
                'message': 'Live wallpaper ready',
                'errorCode': 'none',
              };
            case 'getVideoThumbnail':
              return Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
            case 'clearCache':
              return <String, dynamic>{
                'success': true,
                'message': 'Cache cleared',
                'errorCode': 'none',
              };
            case 'getCacheSize':
              return 1048576; // 1 MB
            case 'setMaxCacheSize':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // ================================================================
  // WallpaperSource Tests
  // ================================================================

  group('WallpaperSource', () {
    group('asset constructor', () {
      test('creates valid asset source', () {
        final source = WallpaperSource.asset('assets/wallpaper.jpg');
        expect(source.type, WallpaperSourceType.asset);
        expect(source.path, 'assets/wallpaper.jpg');
      });

      test('trims whitespace from path', () {
        final source = WallpaperSource.asset('  assets/bg.jpg  ');
        expect(source.path, 'assets/bg.jpg');
      });

      test('throws on empty string', () {
        expect(() => WallpaperSource.asset(''), throwsA(isA<ArgumentError>()));
      });

      test('throws on whitespace-only string', () {
        expect(
          () => WallpaperSource.asset('   '),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('file constructor', () {
      test('creates valid file source', () {
        final source = WallpaperSource.file('/storage/emulated/0/bg.jpg');
        expect(source.type, WallpaperSourceType.file);
        expect(source.path, '/storage/emulated/0/bg.jpg');
      });

      test('throws on empty string', () {
        expect(() => WallpaperSource.file(''), throwsA(isA<ArgumentError>()));
      });
    });

    group('url constructor', () {
      test('creates valid http URL source', () {
        final source = WallpaperSource.url('http://example.com/bg.jpg');
        expect(source.type, WallpaperSourceType.url);
        expect(source.path, 'http://example.com/bg.jpg');
      });

      test('creates valid https URL source', () {
        final source = WallpaperSource.url('https://example.com/bg.jpg');
        expect(source.type, WallpaperSourceType.url);
      });

      test('trims whitespace from URL', () {
        final source = WallpaperSource.url('  https://example.com/bg.jpg  ');
        expect(source.path, 'https://example.com/bg.jpg');
      });

      test('throws on empty string', () {
        expect(() => WallpaperSource.url(''), throwsA(isA<ArgumentError>()));
      });

      test('throws on missing scheme', () {
        expect(
          () => WallpaperSource.url('example.com/bg.jpg'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on non-http scheme', () {
        expect(
          () => WallpaperSource.url('ftp://example.com/bg.jpg'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on invalid URL format', () {
        expect(
          () => WallpaperSource.url('not a url at all'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('serialization', () {
      test('toMap contains correct keys', () {
        final source = WallpaperSource.asset('assets/bg.jpg');
        final map = source.toMap();
        expect(map, hasLength(2));
        expect(map['type'], 'asset');
        expect(map['path'], 'assets/bg.jpg');
      });

      test('toMap for URL source', () {
        final source = WallpaperSource.url('https://example.com/bg.jpg');
        final map = source.toMap();
        expect(map['type'], 'url');
        expect(map['path'], 'https://example.com/bg.jpg');
      });

      test('toMap for file source', () {
        final source = WallpaperSource.file('/data/bg.jpg');
        final map = source.toMap();
        expect(map['type'], 'file');
        expect(map['path'], '/data/bg.jpg');
      });
    });

    group('equality', () {
      test('equal sources are equal', () {
        final a = WallpaperSource.url('https://example.com/bg.jpg');
        final b = WallpaperSource.url('https://example.com/bg.jpg');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different paths are not equal', () {
        final a = WallpaperSource.url('https://example.com/bg1.jpg');
        final b = WallpaperSource.url('https://example.com/bg2.jpg');
        expect(a, isNot(equals(b)));
      });

      test('different types are not equal', () {
        final a = WallpaperSource.asset('bg.jpg');
        final b = WallpaperSource.file('bg.jpg');
        expect(a, isNot(equals(b)));
      });
    });

    test('toString is descriptive', () {
      final source = WallpaperSource.asset('assets/bg.jpg');
      expect(
        source.toString(),
        'WallpaperSource(type: asset, path: assets/bg.jpg)',
      );
    });
  });

  // ================================================================
  // WallpaperTarget Tests
  // ================================================================

  group('WallpaperTarget', () {
    test('has correct values', () {
      expect(WallpaperTarget.values, hasLength(3));
      expect(WallpaperTarget.home.name, 'home');
      expect(WallpaperTarget.lock.name, 'lock');
      expect(WallpaperTarget.both.name, 'both');
    });
  });

  // ================================================================
  // WallpaperErrorCode Tests
  // ================================================================

  group('WallpaperErrorCode', () {
    test('has all expected values', () {
      expect(WallpaperErrorCode.values.length, greaterThanOrEqualTo(10));
      expect(WallpaperErrorCode.values, contains(WallpaperErrorCode.none));
      expect(
        WallpaperErrorCode.values,
        contains(WallpaperErrorCode.sourceNotFound),
      );
      expect(
        WallpaperErrorCode.values,
        contains(WallpaperErrorCode.downloadFailed),
      );
      expect(
        WallpaperErrorCode.values,
        contains(WallpaperErrorCode.unsupported),
      );
      expect(
        WallpaperErrorCode.values,
        contains(WallpaperErrorCode.permissionDenied),
      );
      expect(
        WallpaperErrorCode.values,
        contains(WallpaperErrorCode.applyFailed),
      );
      expect(
        WallpaperErrorCode.values,
        contains(WallpaperErrorCode.videoError),
      );
      expect(
        WallpaperErrorCode.values,
        contains(WallpaperErrorCode.thumbnailFailed),
      );
      expect(
        WallpaperErrorCode.values,
        contains(WallpaperErrorCode.cacheFailed),
      );
      expect(
        WallpaperErrorCode.values,
        contains(WallpaperErrorCode.manufacturerRestriction),
      );
      expect(WallpaperErrorCode.values, contains(WallpaperErrorCode.unknown));
    });

    group('fromString parsing', () {
      test('parses known code', () {
        expect(
          WallpaperErrorCodeParsing.fromString('downloadFailed'),
          WallpaperErrorCode.downloadFailed,
        );
      });

      test('returns none for null', () {
        expect(
          WallpaperErrorCodeParsing.fromString(null),
          WallpaperErrorCode.none,
        );
      });

      test('returns none for empty string', () {
        expect(
          WallpaperErrorCodeParsing.fromString(''),
          WallpaperErrorCode.none,
        );
      });

      test('returns unknown for unrecognized code', () {
        expect(
          WallpaperErrorCodeParsing.fromString('totallyFakeCode'),
          WallpaperErrorCode.unknown,
        );
      });

      test('parses all valid codes', () {
        for (final code in WallpaperErrorCode.values) {
          final parsed = WallpaperErrorCodeParsing.fromString(code.name);
          expect(parsed, code, reason: 'Failed to parse: ${code.name}');
        }
      });
    });
  });

  // ================================================================
  // WallpaperResult Tests
  // ================================================================

  group('WallpaperResult', () {
    test('creates success result', () {
      const result = WallpaperResult(success: true, message: 'Done');
      expect(result.success, isTrue);
      expect(result.isError, isFalse);
      expect(result.errorCode, WallpaperErrorCode.none);
    });

    test('creates error result', () {
      const result = WallpaperResult(
        success: false,
        message: 'Failed',
        errorCode: WallpaperErrorCode.downloadFailed,
      );
      expect(result.success, isFalse);
      expect(result.isError, isTrue);
      expect(result.errorCode, WallpaperErrorCode.downloadFailed);
    });

    group('fromMap', () {
      test('parses success map', () {
        final result = WallpaperResult.fromMap({
          'success': true,
          'message': 'Wallpaper set',
          'errorCode': 'none',
        });
        expect(result.success, isTrue);
        expect(result.message, 'Wallpaper set');
        expect(result.errorCode, WallpaperErrorCode.none);
      });

      test('parses error map', () {
        final result = WallpaperResult.fromMap({
          'success': false,
          'message': 'Download failed: HTTP 404',
          'errorCode': 'downloadFailed',
        });
        expect(result.success, isFalse);
        expect(result.message, 'Download failed: HTTP 404');
        expect(result.errorCode, WallpaperErrorCode.downloadFailed);
      });

      test('handles missing success key', () {
        final result = WallpaperResult.fromMap({'message': 'Something'});
        expect(result.success, isFalse);
      });

      test('handles missing message key', () {
        final result = WallpaperResult.fromMap({'success': true});
        expect(result.message, 'Unknown result');
      });

      test('handles missing errorCode key', () {
        final result = WallpaperResult.fromMap({
          'success': false,
          'message': 'Error',
        });
        expect(result.errorCode, WallpaperErrorCode.none);
      });

      test('handles unknown errorCode string', () {
        final result = WallpaperResult.fromMap({
          'success': false,
          'message': 'Error',
          'errorCode': 'thisCodeDoesNotExist',
        });
        expect(result.errorCode, WallpaperErrorCode.unknown);
      });
    });

    group('equality', () {
      test('equal results are equal', () {
        const a = WallpaperResult(
          success: true,
          message: 'OK',
          errorCode: WallpaperErrorCode.none,
        );
        const b = WallpaperResult(
          success: true,
          message: 'OK',
          errorCode: WallpaperErrorCode.none,
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different results are not equal', () {
        const a = WallpaperResult(success: true, message: 'OK');
        const b = WallpaperResult(success: false, message: 'OK');
        expect(a, isNot(equals(b)));
      });
    });

    test('toString is descriptive', () {
      const result = WallpaperResult(
        success: true,
        message: 'Done',
        errorCode: WallpaperErrorCode.none,
      );
      expect(result.toString(), contains('success: true'));
      expect(result.toString(), contains('Done'));
      expect(result.toString(), contains('none'));
    });
  });

  // ================================================================
  // Method Channel Integration Tests
  // ================================================================

  group('FlutterWallpaperPlus.setImageWallpaper', () {
    test('sends correct arguments via method channel', () async {
      final result = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://example.com/bg.jpg'),
        target: WallpaperTarget.both,
        successMessage: 'Custom success msg',
        errorMessage: 'Custom error msg',
        showToast: false,
      );

      expect(result.success, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'setImageWallpaper');

      final args = log.first.arguments as Map;
      expect(args['target'], 'both');
      expect(args['showToast'], false);
      expect(args['successMessage'], 'Custom success msg');
      expect(args['errorMessage'], 'Custom error msg');

      final source = args['source'] as Map;
      expect(source['type'], 'url');
      expect(source['path'], 'https://example.com/bg.jpg');
    });

    test('uses default messages when not specified', () async {
      await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.asset('assets/bg.jpg'),
        target: WallpaperTarget.home,
      );

      final args = log.first.arguments as Map;
      expect(args['successMessage'], 'Wallpaper set successfully');
      expect(args['errorMessage'], 'Failed to set wallpaper');
      expect(args['showToast'], true);
    });
  });

  group('FlutterWallpaperPlus.setVideoWallpaper', () {
    test('sends correct arguments including audio and loop', () async {
      final result = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.file('/path/to/video.mp4'),
        target: WallpaperTarget.home,
        enableAudio: true,
        loop: false,
        successMessage: 'Live!',
      );

      expect(result.success, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'setVideoWallpaper');

      final args = log.first.arguments as Map;
      expect(args['enableAudio'], true);
      expect(args['loop'], false);
      expect(args['target'], 'home');
      expect(args['successMessage'], 'Live!');
    });

    test('uses default audio and loop values', () async {
      await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://example.com/video.mp4'),
        target: WallpaperTarget.both,
      );

      final args = log.first.arguments as Map;
      expect(args['enableAudio'], false);
      expect(args['loop'], true);
    });
  });

  group('FlutterWallpaperPlus.getVideoThumbnail', () {
    test('returns thumbnail bytes', () async {
      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://example.com/video.mp4'),
        quality: 50,
      );

      expect(bytes, isNotNull);
      expect(bytes!.length, 4);
      expect(log, hasLength(1));

      final args = log.first.arguments as Map;
      expect(args['quality'], 50);
      expect(args['cache'], true);
    });

    test('clamps quality to valid range', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.asset('assets/video.mp4'),
        quality: 200, // Should be clamped to 100
      );

      final args = log.first.arguments as Map;
      expect(args['quality'], 100);
    });

    test('clamps quality minimum', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.asset('assets/video.mp4'),
        quality: -5, // Should be clamped to 1
      );

      final args = log.first.arguments as Map;
      expect(args['quality'], 1);
    });
  });

  group('FlutterWallpaperPlus.clearCache', () {
    test('returns structured result', () async {
      final result = await FlutterWallpaperPlus.clearCache();
      expect(result.success, isTrue);
      expect(result.message, 'Cache cleared');
      expect(log, hasLength(1));
      expect(log.first.method, 'clearCache');
    });
  });

  group('FlutterWallpaperPlus.getCacheSize', () {
    test('returns size in bytes', () async {
      final size = await FlutterWallpaperPlus.getCacheSize();
      expect(size, 1048576);
      expect(log, hasLength(1));
      expect(log.first.method, 'getCacheSize');
    });
  });

  group('FlutterWallpaperPlus.setMaxCacheSize', () {
    test('sends maxBytes argument', () async {
      await FlutterWallpaperPlus.setMaxCacheSize(500 * 1024 * 1024);
      expect(log, hasLength(1));
      expect(log.first.method, 'setMaxCacheSize');
      final args = log.first.arguments as Map;
      expect(args['maxBytes'], 500 * 1024 * 1024);
    });

    test('throws on zero', () {
      expect(
        () => FlutterWallpaperPlus.setMaxCacheSize(0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on negative', () {
      expect(
        () => FlutterWallpaperPlus.setMaxCacheSize(-100),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ================================================================
  // Error handling tests
  // ================================================================

  group('Error handling', () {
    test('handles PlatformException in setImageWallpaper', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw PlatformException(
              code: 'permissionDenied',
              message: 'SET_WALLPAPER not granted',
            );
          });

      final result = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://example.com/bg.jpg'),
        target: WallpaperTarget.home,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.permissionDenied);
      expect(result.message, contains('SET_WALLPAPER'));
    });

    test('handles MissingPluginException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw MissingPluginException('Not implemented');
          });

      final result = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.asset('assets/bg.jpg'),
        target: WallpaperTarget.home,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.unsupported);
      expect(result.message, contains('Android'));
    });

    test('handles null response from platform', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            return null;
          });

      final result = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://example.com/bg.jpg'),
        target: WallpaperTarget.home,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.unknown);
    });

    test('thumbnail returns null on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw PlatformException(code: 'thumbnailFailed');
          });

      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://example.com/video.mp4'),
      );

      expect(bytes, isNull);
    });

    test('getCacheSize returns 0 on error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw PlatformException(code: 'cacheFailed');
          });

      final size = await FlutterWallpaperPlus.getCacheSize();
      expect(size, 0);
    });
  });
}
