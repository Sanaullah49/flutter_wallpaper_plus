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
  String _status = 'Ready — tap a button to test';
  bool _isLoading = false;

  // Sample image URLs (high quality, free to use)
  static const _sampleImageUrl =
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb'
      '?w=1080&q=80';

  static const _sampleImageUrl2 =
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05'
      '?w=1080&q=80';

  void _setStatus(String status) {
    if (mounted) {
      setState(() {
        _status = status;
      });
    }
  }

  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  // ================================================================
  // Image Wallpaper Tests
  // ================================================================

  Future<void> _setImageFromUrlBoth() async {
    _setLoading(true);
    _setStatus('Downloading and setting wallpaper (both screens)...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl),
      target: WallpaperTarget.both,
      successMessage: 'Nature wallpaper applied to both screens!',
      errorMessage: 'Could not set wallpaper',
      showToast: true,
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _setImageFromUrlHome() async {
    _setLoading(true);
    _setStatus('Setting wallpaper (home screen only)...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl2),
      target: WallpaperTarget.home,
      successMessage: 'Home screen wallpaper updated!',
      showToast: true,
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _setImageFromUrlLock() async {
    _setLoading(true);
    _setStatus('Setting wallpaper (lock screen only)...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl),
      target: WallpaperTarget.lock,
      successMessage: 'Lock screen wallpaper updated!',
      showToast: true,
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _setImageFromAsset() async {
    _setLoading(true);
    _setStatus('Setting wallpaper from asset...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.asset('assets/sample_wallpaper.jpg'),
      target: WallpaperTarget.both,
      successMessage: 'Asset wallpaper applied!',
      showToast: true,
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _testInvalidUrl() async {
    _setLoading(true);
    _setStatus('Testing error handling (invalid URL)...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(
        'https://invalid.example.com/nonexistent.jpg',
      ),
      target: WallpaperTarget.home,
      errorMessage: 'This was expected to fail!',
      showToast: true,
    );

    _setLoading(false);
    _setStatus(
      '${result.success ? "✅" : "⚠️"} ${result.message}\n'
      'Error code: ${result.errorCode.name}\n'
      '(This error was intentional — testing error handling)',
    );
  }

  Future<void> _testCachedDownload() async {
    _setLoading(true);
    _setStatus('First call: downloading...');

    // First call — downloads and caches
    final stopwatch1 = Stopwatch()..start();
    final result1 = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl),
      target: WallpaperTarget.home,
      showToast: false,
    );
    stopwatch1.stop();

    if (!result1.success) {
      _setLoading(false);
      _setStatus('❌ First call failed: ${result1.message}');
      return;
    }

    _setStatus(
      'First call: ${stopwatch1.elapsedMilliseconds}ms\n'
      'Second call: using cache...',
    );

    // Second call — should use cache (much faster)
    final stopwatch2 = Stopwatch()..start();
    await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl),
      target: WallpaperTarget.home,
      showToast: false,
    );
    stopwatch2.stop();

    _setLoading(false);
    _setStatus(
      '✅ Cache performance test\n'
      'First call (download): ${stopwatch1.elapsedMilliseconds}ms\n'
      'Second call (cached): ${stopwatch2.elapsedMilliseconds}ms\n'
      'Speedup: ${(stopwatch1.elapsedMilliseconds / (stopwatch2.elapsedMilliseconds == 0 ? 1 : stopwatch2.elapsedMilliseconds)).toStringAsFixed(1)}x faster',
    );
  }

  // ================================================================
  // Cache Operations
  // ================================================================

  Future<void> _getCacheSize() async {
    final size = await FlutterWallpaperPlus.getCacheSize();
    final sizeMB = (size / (1024 * 1024)).toStringAsFixed(2);
    _setStatus('📦 Cache size: $sizeMB MB ($size bytes)');
  }

  Future<void> _clearCache() async {
    _setLoading(true);
    _setStatus('Clearing cache...');

    final result = await FlutterWallpaperPlus.clearCache();

    _setLoading(false);
    _setStatus(result.success ? '✅ ${result.message}' : '❌ ${result.message}');
  }

  // ================================================================
  // Build
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpaper Plus — Phase 2'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Cache size',
            onPressed: _getCacheSize,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear cache',
            onPressed: _clearCache,
          ),
        ],
      ),
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

            // --- Image Wallpaper from URL ---
            _buildSectionHeader(context, 'Image Wallpaper — URL'),

            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _setImageFromUrlBoth,
              icon: const Icon(Icons.wallpaper),
              label: const Text('Set URL → Both Screens'),
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _setImageFromUrlHome,
                    icon: const Icon(Icons.home),
                    label: const Text('Home Only'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _setImageFromUrlLock,
                    icon: const Icon(Icons.lock),
                    label: const Text('Lock Only'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- Image Wallpaper from Asset ---
            _buildSectionHeader(context, 'Image Wallpaper — Asset'),

            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _setImageFromAsset,
              icon: const Icon(Icons.folder),
              label: const Text('Set Asset → Both Screens'),
            ),

            const SizedBox(height: 24),

            // --- Performance & Error Tests ---
            _buildSectionHeader(context, 'Tests'),

            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _testCachedDownload,
              icon: const Icon(Icons.speed),
              label: const Text('Cache Performance Test'),
            ),

            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _testInvalidUrl,
              icon: const Icon(Icons.error_outline),
              label: const Text('Test Error Handling (Bad URL)'),
            ),

            const SizedBox(height: 24),

            // --- Dart API Validation ---
            _buildSectionHeader(context, 'Dart API Validation'),

            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                try {
                  final assetSource = WallpaperSource.asset('assets/test.jpg');
                  final fileSource = WallpaperSource.file('/storage/test.jpg');
                  final urlSource = WallpaperSource.url(
                    'https://example.com/bg.jpg',
                  );

                  final map = urlSource.toMap();

                  final urlSource2 = WallpaperSource.url(
                    'https://example.com/bg.jpg',
                  );
                  final isEqual = urlSource == urlSource2;

                  _setStatus(
                    '✅ All Dart API validations passed!\n'
                    'Asset: ${assetSource.type.name}\n'
                    'File: ${fileSource.type.name}\n'
                    'URL: ${urlSource.type.name}\n'
                    'Serialization: ${map.keys.join(", ")}\n'
                    'Equality: $isEqual',
                  );
                } catch (e) {
                  _setStatus('❌ Validation failed: $e');
                }
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Validate Dart API'),
            ),

            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                try {
                  WallpaperSource.url('not-a-valid-url');
                  _setStatus('❌ Should have thrown ArgumentError!');
                } on ArgumentError catch (e) {
                  _setStatus(
                    '✅ Input validation works!\n'
                    'Caught: ${e.message}',
                  );
                }
              },
              icon: const Icon(Icons.security),
              label: const Text('Test Input Validation'),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}
