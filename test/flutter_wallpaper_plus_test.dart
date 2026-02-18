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
              return Uint8List.fromList([
                0xFF, 0xD8, 0xFF, 0xE0, // JPEG magic bytes
                0x00, 0x10, 0x4A, 0x46,
              ]);
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
  // WallpaperSource
  // ================================================================

  group('WallpaperSource', () {
    group('asset', () {
      test('creates valid source', () {
        final s = WallpaperSource.asset('assets/bg.jpg');
        expect(s.type, WallpaperSourceType.asset);
        expect(s.path, 'assets/bg.jpg');
      });

      test('trims whitespace', () {
        expect(WallpaperSource.asset('  a.jpg  ').path, 'a.jpg');
      });

      test('throws on empty', () {
        expect(() => WallpaperSource.asset(''), throwsA(isA<ArgumentError>()));
      });

      test('throws on whitespace', () {
        expect(
          () => WallpaperSource.asset('  '),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('file', () {
      test('creates valid source', () {
        final s = WallpaperSource.file('/path/bg.jpg');
        expect(s.type, WallpaperSourceType.file);
      });

      test('throws on empty', () {
        expect(() => WallpaperSource.file(''), throwsA(isA<ArgumentError>()));
      });
    });

    group('url', () {
      test('http', () {
        final s = WallpaperSource.url('http://example.com/bg.jpg');
        expect(s.type, WallpaperSourceType.url);
      });

      test('https', () {
        final s = WallpaperSource.url('https://example.com/bg.jpg');
        expect(s.type, WallpaperSourceType.url);
      });

      test('trims', () {
        expect(
          WallpaperSource.url('  https://e.com/b  ').path,
          'https://e.com/b',
        );
      });

      test('throws on empty', () {
        expect(() => WallpaperSource.url(''), throwsA(isA<ArgumentError>()));
      });

      test('throws on no scheme', () {
        expect(
          () => WallpaperSource.url('example.com'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on ftp', () {
        expect(
          () => WallpaperSource.url('ftp://e.com/b'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on garbage', () {
        expect(
          () => WallpaperSource.url('not a url'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('serialization', () {
      test('asset', () {
        final m = WallpaperSource.asset('a.jpg').toMap();
        expect(m, {'type': 'asset', 'path': 'a.jpg'});
      });

      test('file', () {
        final m = WallpaperSource.file('/b.jpg').toMap();
        expect(m, {'type': 'file', 'path': '/b.jpg'});
      });

      test('url', () {
        final m = WallpaperSource.url('https://e.com/c.jpg').toMap();
        expect(m, {'type': 'url', 'path': 'https://e.com/c.jpg'});
      });
    });

    group('equality', () {
      test('equal', () {
        final a = WallpaperSource.url('https://e.com/b');
        final b = WallpaperSource.url('https://e.com/b');
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('different path', () {
        expect(
          WallpaperSource.url('https://e.com/1'),
          isNot(equals(WallpaperSource.url('https://e.com/2'))),
        );
      });

      test('different type', () {
        expect(
          WallpaperSource.asset('x'),
          isNot(equals(WallpaperSource.file('x'))),
        );
      });
    });

    test('toString', () {
      expect(
        WallpaperSource.asset('a.jpg').toString(),
        'WallpaperSource(type: asset, path: a.jpg)',
      );
    });
  });

  // ================================================================
  // WallpaperTarget
  // ================================================================

  group('WallpaperTarget', () {
    test('values', () {
      expect(WallpaperTarget.values, hasLength(3));
      expect(WallpaperTarget.home.name, 'home');
      expect(WallpaperTarget.lock.name, 'lock');
      expect(WallpaperTarget.both.name, 'both');
    });
  });

  // ================================================================
  // WallpaperErrorCode
  // ================================================================

  group('WallpaperErrorCode', () {
    test('count', () {
      expect(WallpaperErrorCode.values.length, greaterThanOrEqualTo(10));
    });

    test('fromString known', () {
      expect(
        WallpaperErrorCodeParsing.fromString('downloadFailed'),
        WallpaperErrorCode.downloadFailed,
      );
    });

    test('fromString null', () {
      expect(
        WallpaperErrorCodeParsing.fromString(null),
        WallpaperErrorCode.none,
      );
    });

    test('fromString empty', () {
      expect(WallpaperErrorCodeParsing.fromString(''), WallpaperErrorCode.none);
    });

    test('fromString unknown', () {
      expect(
        WallpaperErrorCodeParsing.fromString('xyz'),
        WallpaperErrorCode.unknown,
      );
    });

    test('all codes parse', () {
      for (final c in WallpaperErrorCode.values) {
        expect(WallpaperErrorCodeParsing.fromString(c.name), c);
      }
    });
  });

  // ================================================================
  // WallpaperResult
  // ================================================================

  group('WallpaperResult', () {
    test('success', () {
      const r = WallpaperResult(success: true, message: 'OK');
      expect(r.success, isTrue);
      expect(r.isError, isFalse);
      expect(r.errorCode, WallpaperErrorCode.none);
    });

    test('error', () {
      const r = WallpaperResult(
        success: false,
        message: 'F',
        errorCode: WallpaperErrorCode.downloadFailed,
      );
      expect(r.isError, isTrue);
    });

    test('fromMap success', () {
      final r = WallpaperResult.fromMap({
        'success': true,
        'message': 'OK',
        'errorCode': 'none',
      });
      expect(r.success, isTrue);
    });

    test('fromMap error', () {
      final r = WallpaperResult.fromMap({
        'success': false,
        'message': 'E',
        'errorCode': 'downloadFailed',
      });
      expect(r.errorCode, WallpaperErrorCode.downloadFailed);
    });

    test('fromMap defaults', () {
      final r = WallpaperResult.fromMap(<String, dynamic>{});
      expect(r.success, isFalse);
      expect(r.message, 'Unknown result');
    });

    test('equality', () {
      const a = WallpaperResult(success: true, message: 'OK');
      const b = WallpaperResult(success: true, message: 'OK');
      expect(a, equals(b));
    });

    test('toString', () {
      const r = WallpaperResult(success: true, message: 'D');
      expect(r.toString(), contains('true'));
    });
  });

  // ================================================================
  // setImageWallpaper
  // ================================================================

  group('setImageWallpaper', () {
    test('url with all params', () async {
      final r = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://e.com/bg.jpg'),
        target: WallpaperTarget.both,
        successMessage: 'S',
        errorMessage: 'E',
        showToast: false,
      );

      expect(r.success, isTrue);
      final a = log.first.arguments as Map;
      expect(a['target'], 'both');
      expect(a['showToast'], false);
      expect((a['source'] as Map)['type'], 'url');
    });

    test('asset source', () async {
      await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.asset('a.jpg'),
        target: WallpaperTarget.home,
      );
      final a = log.first.arguments as Map;
      expect((a['source'] as Map)['type'], 'asset');
    });

    test('file source', () async {
      await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.file('/b.jpg'),
        target: WallpaperTarget.lock,
      );
      final a = log.first.arguments as Map;
      expect((a['source'] as Map)['type'], 'file');
      expect(a['target'], 'lock');
    });

    test('defaults', () async {
      await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.asset('a.jpg'),
        target: WallpaperTarget.home,
      );
      final a = log.first.arguments as Map;
      expect(a['successMessage'], 'Wallpaper set successfully');
      expect(a['showToast'], true);
    });

    test('all targets', () async {
      for (final t in WallpaperTarget.values) {
        log.clear();
        await FlutterWallpaperPlus.setImageWallpaper(
          source: WallpaperSource.url('https://e.com/b'),
          target: t,
        );
        expect((log.first.arguments as Map)['target'], t.name);
      }
    });

    test('error responses', () async {
      for (final code in [
        'downloadFailed',
        'permissionDenied',
        'manufacturerRestriction',
        'applyFailed',
        'sourceNotFound',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (c) async {
              return <String, dynamic>{
                'success': false,
                'message': 'err',
                'errorCode': code,
              };
            });

        final r = await FlutterWallpaperPlus.setImageWallpaper(
          source: WallpaperSource.url('https://e.com/b'),
          target: WallpaperTarget.home,
        );
        expect(r.success, isFalse);
        expect(r.errorCode.name, code);
      }
    });

    test('PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            throw PlatformException(
              code: 'permissionDenied',
              message: 'denied',
            );
          });

      final r = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://e.com/b'),
        target: WallpaperTarget.home,
      );
      expect(r.errorCode, WallpaperErrorCode.permissionDenied);
    });

    test('MissingPluginException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            throw MissingPluginException();
          });

      final r = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.asset('a'),
        target: WallpaperTarget.home,
      );
      expect(r.errorCode, WallpaperErrorCode.unsupported);
    });

    test('null response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async => null);

      final r = await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url('https://e.com/b'),
        target: WallpaperTarget.home,
      );
      expect(r.success, isFalse);
    });
  });

  // ================================================================
  // setVideoWallpaper
  // ================================================================

  group('setVideoWallpaper', () {
    test('all params', () async {
      final r = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://e.com/v.mp4'),
        target: WallpaperTarget.home,
        enableAudio: true,
        loop: false,
        successMessage: 'S',
        errorMessage: 'E',
        showToast: false,
      );

      expect(r.success, isTrue);
      final a = log.first.arguments as Map;
      expect(a['enableAudio'], true);
      expect(a['loop'], false);
      expect(a['target'], 'home');
      expect(a['showToast'], false);
    });

    test('defaults', () async {
      await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://e.com/v.mp4'),
        target: WallpaperTarget.home,
      );
      final a = log.first.arguments as Map;
      expect(a['enableAudio'], false);
      expect(a['loop'], true);
      expect(a['successMessage'], 'Live wallpaper set successfully');
    });

    test('asset', () async {
      await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.asset('rain.mp4'),
        target: WallpaperTarget.home,
      );
      final a = log.first.arguments as Map;
      expect((a['source'] as Map)['type'], 'asset');
    });

    test('file', () async {
      await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.file('/v.mp4'),
        target: WallpaperTarget.home,
      );
      expect(((log.first.arguments as Map)['source'] as Map)['type'], 'file');
    });

    test('all targets', () async {
      for (final t in WallpaperTarget.values) {
        log.clear();
        await FlutterWallpaperPlus.setVideoWallpaper(
          source: WallpaperSource.url('https://e.com/v'),
          target: t,
        );
        expect((log.first.arguments as Map)['target'], t.name);
      }
    });

    test('unsupported', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            return <String, dynamic>{
              'success': false,
              'message': 'not supported',
              'errorCode': 'unsupported',
            };
          });
      final r = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://e.com/v'),
        target: WallpaperTarget.home,
      );
      expect(r.errorCode, WallpaperErrorCode.unsupported);
    });

    test('PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            throw PlatformException(code: 'videoError', message: 'codec');
          });
      final r = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://e.com/v'),
        target: WallpaperTarget.home,
      );
      expect(r.errorCode, WallpaperErrorCode.videoError);
    });

    test('null response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async => null);
      final r = await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url('https://e.com/v'),
        target: WallpaperTarget.home,
      );
      expect(r.success, isFalse);
    });
  });

  // ================================================================
  // getVideoThumbnail (Phase 4)
  // ================================================================

  group('getVideoThumbnail', () {
    test('returns bytes from URL source', () async {
      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://e.com/v.mp4'),
        quality: 50,
      );

      expect(bytes, isNotNull);
      expect(bytes!.length, 8);
      expect(bytes[0], 0xFF); // JPEG magic byte
      expect(bytes[1], 0xD8);

      final a = log.first.arguments as Map;
      expect(a['quality'], 50);
      expect(a['cache'], true);
      expect((a['source'] as Map)['type'], 'url');
    });

    test('returns bytes from asset source', () async {
      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.asset('assets/video.mp4'),
        quality: 30,
      );

      expect(bytes, isNotNull);
      final a = log.first.arguments as Map;
      expect((a['source'] as Map)['type'], 'asset');
    });

    test('returns bytes from file source', () async {
      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.file('/path/video.mp4'),
      );

      expect(bytes, isNotNull);
      final a = log.first.arguments as Map;
      expect((a['source'] as Map)['type'], 'file');
    });

    test('default quality is 30', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://e.com/v.mp4'),
      );
      final a = log.first.arguments as Map;
      expect(a['quality'], 30);
    });

    test('default cache is true', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://e.com/v.mp4'),
      );
      final a = log.first.arguments as Map;
      expect(a['cache'], true);
    });

    test('cache false', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://e.com/v.mp4'),
        cache: false,
      );
      final a = log.first.arguments as Map;
      expect(a['cache'], false);
    });

    test('clamps quality max to 100', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.asset('v.mp4'),
        quality: 200,
      );
      expect((log.first.arguments as Map)['quality'], 100);
    });

    test('clamps quality min to 1', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.asset('v.mp4'),
        quality: -5,
      );
      expect((log.first.arguments as Map)['quality'], 1);
    });

    test('clamps quality 0 to 1', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.asset('v.mp4'),
        quality: 0,
      );
      expect((log.first.arguments as Map)['quality'], 1);
    });

    test('quality 1 passes as 1', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.asset('v.mp4'),
        quality: 1,
      );
      expect((log.first.arguments as Map)['quality'], 1);
    });

    test('quality 100 passes as 100', () async {
      await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.asset('v.mp4'),
        quality: 100,
      );
      expect((log.first.arguments as Map)['quality'], 100);
    });

    test('returns null on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            throw PlatformException(code: 'thumbnailFailed');
          });
      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://e.com/v.mp4'),
      );
      expect(bytes, isNull);
    });

    test('returns null on MissingPluginException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            throw MissingPluginException();
          });
      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://e.com/v.mp4'),
      );
      expect(bytes, isNull);
    });

    test('returns null on generic exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            throw Exception('something broke');
          });
      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://e.com/v.mp4'),
      );
      expect(bytes, isNull);
    });

    test('returns null when platform returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async => null);
      final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
        source: WallpaperSource.url('https://e.com/v.mp4'),
      );
      expect(bytes, isNull);
    });
  });

  // ================================================================
  // Cache Management
  // ================================================================

  group('Cache management', () {
    test('clearCache', () async {
      final r = await FlutterWallpaperPlus.clearCache();
      expect(r.success, isTrue);
      expect(log.first.method, 'clearCache');
    });

    test('getCacheSize', () async {
      final s = await FlutterWallpaperPlus.getCacheSize();
      expect(s, 1048576);
    });

    test('setMaxCacheSize', () async {
      await FlutterWallpaperPlus.setMaxCacheSize(500 * 1024 * 1024);
      expect((log.first.arguments as Map)['maxBytes'], 500 * 1024 * 1024);
    });

    test('setMaxCacheSize throws on 0', () {
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
          .setMockMethodCallHandler(channel, (c) async {
            throw PlatformException(code: 'e');
          });
      expect(await FlutterWallpaperPlus.getCacheSize(), 0);
    });
  });
}
