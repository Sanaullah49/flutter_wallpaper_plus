import 'package:flutter/material.dart';
import 'package:flutter_wallpaper_plus/flutter_wallpaper_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper Plus Example',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Ready — Phase 1 foundation complete';
  bool _isLoading = false;

  Future<void> _testCacheSize() async {
    setState(() {
      _isLoading = true;
      _status = 'Getting cache size...';
    });

    final size = await FlutterWallpaperPlus.getCacheSize();
    final sizeMB = (size / (1024 * 1024)).toStringAsFixed(2);

    setState(() {
      _isLoading = false;
      _status = 'Cache size: $sizeMB MB ($size bytes)';
    });
  }

  Future<void> _testClearCache() async {
    setState(() {
      _isLoading = true;
      _status = 'Clearing cache...';
    });

    final result = await FlutterWallpaperPlus.clearCache();

    setState(() {
      _isLoading = false;
      _status = result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message} (${result.errorCode.name})';
    });
  }

  Future<void> _testSetMaxCacheSize() async {
    setState(() {
      _isLoading = true;
      _status = 'Setting max cache size to 100 MB...';
    });

    await FlutterWallpaperPlus.setMaxCacheSize(100 * 1024 * 1024);

    setState(() {
      _isLoading = false;
      _status = '✅ Max cache size set to 100 MB';
    });
  }

  Future<void> _testImageWallpaper() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing setImageWallpaper (Phase 2 placeholder)...';
    });

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url('https://example.com/test.jpg'),
      target: WallpaperTarget.both,
    );

    setState(() {
      _isLoading = false;
      _status = result.success
          ? '✅ ${result.message}'
          : '⏳ ${result.message} (${result.errorCode.name})';
    });
  }

  Future<void> _testVideoWallpaper() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing setVideoWallpaper (Phase 3 placeholder)...';
    });

    final result = await FlutterWallpaperPlus.setVideoWallpaper(
      source: WallpaperSource.url('https://example.com/test.mp4'),
      target: WallpaperTarget.home,
    );

    setState(() {
      _isLoading = false;
      _status = result.success
          ? '✅ ${result.message}'
          : '⏳ ${result.message} (${result.errorCode.name})';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallpaper Plus — Phase 1')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Cache operations (fully working in Phase 1)
            Text(
              'Cache Operations (Working)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testCacheSize,
              icon: const Icon(Icons.storage),
              label: const Text('Get Cache Size'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testClearCache,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear Cache'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testSetMaxCacheSize,
              icon: const Icon(Icons.settings),
              label: const Text('Set Max Cache Size (100 MB)'),
            ),

            const SizedBox(height: 24),

            // Placeholder operations (Phase 2-3)
            Text(
              'Wallpaper Operations (Placeholder)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _testImageWallpaper,
              icon: const Icon(Icons.image),
              label: const Text('Test Image Wallpaper (Phase 2)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _testVideoWallpaper,
              icon: const Icon(Icons.videocam),
              label: const Text('Test Video Wallpaper (Phase 3)'),
            ),

            const SizedBox(height: 24),

            // Dart API validation (runs instantly, no platform call)
            Text(
              'Dart API Validation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                try {
                  // Test source creation
                  final assetSource = WallpaperSource.asset('assets/test.jpg');
                  final fileSource = WallpaperSource.file('/storage/test.jpg');
                  final urlSource = WallpaperSource.url(
                    'https://example.com/bg.jpg',
                  );

                  // Test serialization
                  final map = urlSource.toMap();

                  // Test equality
                  final urlSource2 = WallpaperSource.url(
                    'https://example.com/bg.jpg',
                  );
                  final isEqual = urlSource == urlSource2;

                  setState(() {
                    _status =
                        '✅ All Dart API validations passed!\n'
                        'Asset: ${assetSource.type.name}\n'
                        'File: ${fileSource.type.name}\n'
                        'URL: ${urlSource.type.name}\n'
                        'Map keys: ${map.keys.join(", ")}\n'
                        'Equality: $isEqual';
                  });
                } catch (e) {
                  setState(() {
                    _status = '❌ Validation failed: $e';
                  });
                }
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Validate Dart API'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                try {
                  // This should throw ArgumentError
                  WallpaperSource.url('not-a-valid-url');
                  setState(() {
                    _status = '❌ Should have thrown ArgumentError!';
                  });
                } on ArgumentError catch (e) {
                  setState(() {
                    _status =
                        '✅ Input validation works!\n'
                        'Caught: ${e.message}';
                  });
                }
              },
              icon: const Icon(Icons.error_outline),
              label: const Text('Test Input Validation'),
            ),
          ],
        ),
      ),
    );
  }
}
