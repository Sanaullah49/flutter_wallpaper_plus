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
              return 1048576;
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

      test('trims whitespace', () {
        final source = WallpaperSource.asset('  assets/bg.jpg  ');
        expect(source.path, 'assets/bg.jpg');
      });

      test('throws on empty', () {
        expect(() => WallpaperSource.asset(''), throwsA(isA<ArgumentError>()));
      });

      test('throws on whitespace only', () {
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

      test('throws on empty', () {
        expect(() => WallpaperSource.file(''), throwsA(isA<ArgumentError>()));
      });
    });

    group('url constructor', () {
      test('creates valid http URL', () {
        final source = WallpaperSource.url('http://example.com/bg.jpg');
        expect(source.type, WallpaperSourceType.url);
      });

      test('creates valid https URL', () {
        final source = WallpaperSource.url('https://example.com/bg.jpg');
        expect(source.type, WallpaperSourceType.url);
      });

      test('trims whitespace', () {
        final source = WallpaperSource.url('  https://example.com/bg.jpg  ');
        expect(source.path, 'https://example.com/bg.jpg');
      });

      test('throws on empty', () {
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

      test('throws on invalid format', () {
        expect(
          () => WallpaperSource.url('not a url'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('serialization', () {
      test('asset toMap', () {
        final map = WallpaperSource.asset('assets/bg.jpg').toMap();
        expect(map['type'], 'asset');
        expect(map['path'], 'assets/bg.jpg');
      });

      test('url toMap', () {
        final map = WallpaperSource.url('https://example.com/bg.jpg').toMap();
        expect(map['type'], 'url');
        expect(map['path'], 'https://example.com/bg.jpg');
      });

      test('file toMap', () {
        final map = WallpaperSource.file('/data/bg.jpg').toMap();
        expect(map['type'], 'file');
        expect(map['path'], '/data/bg.jpg');
      });
    });

    group('equality', () {
      test('equal sources', () {
        final a = WallpaperSource.url('https://example.com/bg.jpg');
        final b = WallpaperSource.url('https://example.com/bg.jpg');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different paths not equal', () {
        final a = WallpaperSource.url('https://example.com/bg1.jpg');
        final b = WallpaperSource.url('https://example.com/bg2.jpg');
        expect(a, isNot(equals(b)));
      });

      test('different types not equal', () {
        final a = WallpaperSource.asset('bg.jpg');
        final b = WallpaperSource.file('bg.jpg');
        expect(a, isNot(equals(b)));
      });
    });

    test('toString', () {
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
    });

    group('fromString', () {
      test('parses known code', () {
        expect(
          WallpaperErrorCodeParsing.fromString('downloadFailed'),
          WallpaperErrorCode.downloadFailed,
        );
      });

      test('null returns none', () {
        expect(
          WallpaperErrorCodeParsing.fromString(null),
          WallpaperErrorCode.none,
        );
      });

      test('empty returns none', () {
        expect(
          WallpaperErrorCodeParsing.fromString(''),
          WallpaperErrorCode.none,
        );
      });

      test('unknown returns unknown', () {
        expect(
          WallpaperErrorCodeParsing.fromString('fakeCode'),
          WallpaperErrorCode.unknown,
        );
      });

      test('parses all valid codes', () {
        for (final code in WallpaperErrorCode.values) {
          expect(WallpaperErrorCodeParsing.fromString(code.name), code);
        }
      });
    });
  });

  // ================================================================
  // WallpaperResult Tests
  // ================================================================

  group('WallpaperResult', () {
    test('success result', () {
      const r = WallpaperResult(success: true, message: 'OK');
      expect(r.success, isTrue);
      expect(r.isError, isFalse);
      expect(r.errorCode, WallpaperErrorCode.none);
    });

    test('error result', () {
      const r = WallpaperResult(
        success: false,
        message: 'Fail',
        errorCode: WallpaperErrorCode.downloadFailed,
      );
      expect(r.success, isFalse);
      expect(r.isError, isTrue);
    });

    group('fromMap', () {
      test('success map', () {
        final r = WallpaperResult.fromMap({
          'success': true,
          'message': 'OK',
          'errorCode': 'none',
        });
        expect(r.success, isTrue);
        expect(r.message, 'OK');
      });

      test('error map', () {
        final r = WallpaperResult.fromMap({
          'success': false,
          'message': 'HTTP 404',
          'errorCode': 'downloadFailed',
        });
        expect(r.success, isFalse);
        expect(r.errorCode, WallpaperErrorCode.downloadFailed);
      });

      test('missing success defaults false', () {
        final r = WallpaperResult.fromMap({'message': 'X'});
        expect(r.success, isFalse);
      });

      test('missing message defaults', () {
        final r = WallpaperResult.fromMap({'success': true});
        expect(r.message, 'Unknown result');
      });

      test('unknown errorCode', () {
        final r = WallpaperResult.fromMap({
          'success': false,
          'message': 'E',
          'errorCode': 'fake',
        });
        expect(r.errorCode, WallpaperErrorCode.unknown);
      });
    });

    test('equality', () {
      const a = WallpaperResult(success: true, message: 'OK');
      const b = WallpaperResult(success: true, message: 'OK');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString', () {
      const r = WallpaperResult(success: true, message: 'Done');
      expect(r.toString(), contains('success: true'));
      expect(r.toString(), contains('Done'));
    });
  });

  // ================================================================
  // setImageWallpaper Tests
  // ================================================================

  group('setImageWallpaper', () {
    test('URL source with all parameters', () async {
      final result = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://example.com/bg.jpg'),
        target: WallpaperTarget.both,
        successMessage: 'Custom success',
        errorMessage: 'Custom error',
        showToast: false,
      );

      expect(result.success, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'setImageWallpaper');

      final args = log.first.arguments as Map;
      expect(args['target'], 'both');
      expect(args['showToast'], false);
      expect(args['successMessage'], 'Custom success');
      expect(args['errorMessage'], 'Custom error');

      final source = args['source'] as Map;
      expect(source['type'], 'url');
      expect(source['path'], 'https://example.com/bg.jpg');
    });

    test('asset source', () async {
      await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.asset('assets/bg.jpg'),
        target: WallpaperTarget.home,
      );

      final args = log.first.arguments as Map;
      final source = args['source'] as Map;
      expect(source['type'], 'asset');
      expect(args['target'], 'home');
    });

    test('file source', () async {
      await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.file('/storage/bg.jpg'),
        target: WallpaperTarget.lock,
      );

      final args = log.first.arguments as Map;
      final source = args['source'] as Map;
      expect(source['type'], 'file');
      expect(args['target'], 'lock');
    });

    test('default messages', () async {
      await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.asset('assets/bg.jpg'),
        target: WallpaperTarget.home,
      );

      final args = log.first.arguments as Map;
      expect(args['successMessage'], 'Wallpaper set successfully');
      expect(args['errorMessage'], 'Failed to set wallpaper');
      expect(args['showToast'], true);
    });

    test('all targets', () async {
      for (final target in WallpaperTarget.values) {
        log.clear();
        await FlutterWallpaperPlus.setImageWallpaper(
          source: WallpaperSource.url('https://example.com/bg.jpg'),
          target: target,
        );
        final args = log.first.arguments as Map;
        expect(args['target'], target.name);
      }
    });

    test('download failure response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return <String, dynamic>{
              'success': false,
              'message': 'HTTP 404',
              'errorCode': 'downloadFailed',
            };
          });

      final result = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://example.com/missing.jpg'),
        target: WallpaperTarget.home,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.downloadFailed);
    });

    test('permission denied response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return <String, dynamic>{
              'success': false,
              'message': 'Permission denied',
              'errorCode': 'permissionDenied',
            };
          });

      final result = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://example.com/bg.jpg'),
        target: WallpaperTarget.home,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.permissionDenied);
    });

    test('manufacturer restriction response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return <String, dynamic>{
              'success': false,
              'message': 'Blocked by policy',
              'errorCode': 'manufacturerRestriction',
            };
          });

      final result = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://example.com/bg.jpg'),
        target: WallpaperTarget.home,
      );

      expect(result.errorCode, WallpaperErrorCode.manufacturerRestriction);
    });

    test('apply failure response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return <String, dynamic>{
              'success': false,
              'message': 'Too large',
              'errorCode': 'applyFailed',
            };
          });

      final result = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://example.com/huge.jpg'),
        target: WallpaperTarget.both,
      );

      expect(result.errorCode, WallpaperErrorCode.applyFailed);
    });
  });

  // ================================================================
  // setVideoWallpaper Tests (Phase 3)
  // ================================================================

  group('setVideoWallpaper', () {
    test('sends all arguments correctly', () async {
      final result = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://example.com/video.mp4'),
        target: WallpaperTarget.home,
        enableAudio: true,
        loop: false,
        successMessage: 'Video ready!',
        errorMessage: 'Video failed',
        showToast: false,
      );

      expect(result.success, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'setVideoWallpaper');

      final args = log.first.arguments as Map;
      expect(args['enableAudio'], true);
      expect(args['loop'], false);
      expect(args['target'], 'home');
      expect(args['successMessage'], 'Video ready!');
      expect(args['errorMessage'], 'Video failed');
      expect(args['showToast'], false);

      final source = args['source'] as Map;
      expect(source['type'], 'url');
      expect(source['path'], 'https://example.com/video.mp4');
    });

    test('default audio and loop values', () async {
      await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://example.com/video.mp4'),
        target: WallpaperTarget.both,
      );

      final args = log.first.arguments as Map;
      expect(args['enableAudio'], false);
      expect(args['loop'], true);
    });

    test('default messages', () async {
      await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://example.com/video.mp4'),
        target: WallpaperTarget.home,
      );

      final args = log.first.arguments as Map;
      expect(args['successMessage'], 'Live wallpaper set successfully');
      expect(args['errorMessage'], 'Failed to set live wallpaper');
      expect(args['showToast'], true);
    });

    test('asset source', () async {
      await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.asset('assets/rain.mp4'),
        target: WallpaperTarget.home,
      );

      final args = log.first.arguments as Map;
      final source = args['source'] as Map;
      expect(source['type'], 'asset');
      expect(source['path'], 'assets/rain.mp4');
    });

    test('file source', () async {
      await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.file('/storage/video.mp4'),
        target: WallpaperTarget.home,
      );

      final args = log.first.arguments as Map;
      final source = args['source'] as Map;
      expect(source['type'], 'file');
      expect(source['path'], '/storage/video.mp4');
    });

    test('all targets', () async {
      for (final target in WallpaperTarget.values) {
        log.clear();
        await FlutterWallpaperPlus.setVideoWallpaper(
          source: WallpaperSource.url('https://example.com/v.mp4'),
          target: target,
        );
        final args = log.first.arguments as Map;
        expect(args['target'], target.name);
      }
    });

    test('unsupported device response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return <String, dynamic>{
              'success': false,
              'message': 'Live wallpapers not supported',
              'errorCode': 'unsupported',
            };
          });

      final result = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://example.com/v.mp4'),
        target: WallpaperTarget.home,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.unsupported);
    });

    test('download failure response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return <String, dynamic>{
              'success': false,
              'message': 'Download failed',
              'errorCode': 'downloadFailed',
            };
          });

      final result = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://bad.example.com/v.mp4'),
        target: WallpaperTarget.home,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.downloadFailed);
    });

    test('source not found response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return <String, dynamic>{
              'success': false,
              'message': 'Asset not found',
              'errorCode': 'sourceNotFound',
            };
          });

      final result = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.asset('assets/missing.mp4'),
        target: WallpaperTarget.home,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.sourceNotFound);
    });

    test('PlatformException handling', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'videoError',
              message: 'Codec not supported',
            );
          });

      final result = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://example.com/v.mp4'),
        target: WallpaperTarget.home,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.videoError);
    });

    test('MissingPluginException handling', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw MissingPluginException();
          });

      final result = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://example.com/v.mp4'),
        target: WallpaperTarget.home,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.unsupported);
    });

    test('null response handling', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      final result = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://example.com/v.mp4'),
        target: WallpaperTarget.home,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, WallpaperErrorCode.unknown);
    });
  });

  // ================================================================
  // getVideoThumbnail Tests
  // ================================================================

  group('getVideoThumbnail', () {
    test('returns bytes', () async {
      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://example.com/v.mp4'),
        quality: 50,
      );
      expect(bytes, isNotNull);
      expect(bytes!.length, 4);
    });

    test('clamps quality max', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.asset('assets/v.mp4'),
        quality: 200,
      );
      final args = log.first.arguments as Map;
      expect(args['quality'], 100);
    });

    test('clamps quality min', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.asset('assets/v.mp4'),
        quality: -5,
      );
      final args = log.first.arguments as Map;
      expect(args['quality'], 1);
    });

    test('returns null on error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'thumbnailFailed');
          });

      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://example.com/v.mp4'),
      );
      expect(bytes, isNull);
    });
  });

  // ================================================================
  // Cache Management Tests
  // ================================================================

  group('Cache management', () {
    test('clearCache', () async {
      final result = await FlutterWallpaperPlus.clearCache();
      expect(result.success, isTrue);
      expect(log.first.method, 'clearCache');
    });

    test('getCacheSize', () async {
      final size = await FlutterWallpaperPlus.getCacheSize();
      expect(size, 1048576);
    });

    test('setMaxCacheSize', () async {
      await FlutterWallpaperPlus.setMaxCacheSize(500 * 1024 * 1024);
      expect(log.first.method, 'setMaxCacheSize');
      final args = log.first.arguments as Map;
      expect(args['maxBytes'], 500 * 1024 * 1024);
    });

    test('setMaxCacheSize throws on zero', () {
      expect(
        () => FlutterWallpaperPlus.setMaxCacheSize(0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('setMaxCacheSize throws on negative', () {
      expect(
        () => FlutterWallpaperPlus.setMaxCacheSize(-1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getCacheSize returns 0 on error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'error');
          });
      final size = await FlutterWallpaperPlus.getCacheSize();
      expect(size, 0);
    });
  });
}
