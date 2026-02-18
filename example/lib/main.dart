import 'dart:typed_data';

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
  Uint8List? _thumbnailBytes;

  static const _sampleImageUrl =
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb'
      '?w=1080&q=80';

  static const _sampleImageUrl2 =
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05'
      '?w=1080&q=80';

  static const _sampleVideoUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/'
      'sample/ForBiggerBlazes.mp4';

  void _setStatus(String status) {
    if (mounted) setState(() => _status = status);
  }

  void _setLoading(bool loading) {
    if (mounted) setState(() => _isLoading = loading);
  }

  // ================================================================
  // Image Wallpaper
  // ================================================================

  Future<void> _setImageBoth() async {
    _setLoading(true);
    _setStatus('Setting image wallpaper (both screens)...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl),
      target: WallpaperTarget.both,
      successMessage: 'Wallpaper applied to both screens!',
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _setImageHome() async {
    _setLoading(true);
    _setStatus('Setting image wallpaper (home)...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl2),
      target: WallpaperTarget.home,
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _setImageLock() async {
    _setLoading(true);
    _setStatus('Setting image wallpaper (lock)...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl),
      target: WallpaperTarget.lock,
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _setImageAsset() async {
    _setLoading(true);
    _setStatus('Setting wallpaper from asset...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.asset('assets/sample_wallpaper.jpg'),
      target: WallpaperTarget.both,
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  // ================================================================
  // Video Wallpaper
  // ================================================================

  Future<void> _setVideoSilentLoop() async {
    _setLoading(true);
    _setStatus('Preparing video wallpaper (silent, loop)...');

    final result = await FlutterWallpaperPlus.setVideoWallpaper(
      source: WallpaperSource.url(_sampleVideoUrl),
      target: WallpaperTarget.home,
      enableAudio: false,
      loop: true,
      successMessage: 'Video wallpaper ready!',
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _setVideoWithAudio() async {
    _setLoading(true);
    _setStatus('Preparing video wallpaper (audio, loop)...');

    final result = await FlutterWallpaperPlus.setVideoWallpaper(
      source: WallpaperSource.url(_sampleVideoUrl),
      target: WallpaperTarget.home,
      enableAudio: true,
      loop: true,
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _setVideoNoLoop() async {
    _setLoading(true);
    _setStatus('Preparing video wallpaper (no loop)...');

    final result = await FlutterWallpaperPlus.setVideoWallpaper(
      source: WallpaperSource.url(_sampleVideoUrl),
      target: WallpaperTarget.home,
      enableAudio: false,
      loop: false,
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  // ================================================================
  // Thumbnail Generation (Phase 4)
  // ================================================================

  Future<void> _generateThumbnailFromUrl() async {
    _setLoading(true);
    _setStatus('Generating thumbnail from URL...');

    final stopwatch = Stopwatch()..start();

    final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
      source: WallpaperSource.url(_sampleVideoUrl),
      quality: 50,
      cache: true,
    );

    stopwatch.stop();
    _setLoading(false);

    if (bytes != null) {
      setState(() => _thumbnailBytes = bytes);
      _setStatus(
        '✅ Thumbnail generated!\n'
        'Size: ${(bytes.length / 1024).toStringAsFixed(1)} KB\n'
        'Time: ${stopwatch.elapsedMilliseconds}ms',
      );
    } else {
      _setStatus('❌ Thumbnail generation failed');
    }
  }

  Future<void> _generateThumbnailCached() async {
    _setLoading(true);

    // First call — generates and caches
    final stopwatch1 = Stopwatch()..start();
    final bytes1 = await FlutterWallpaperPlus.getVideoThumbnail(
      source: WallpaperSource.url(_sampleVideoUrl),
      quality: 50,
      cache: true,
    );
    stopwatch1.stop();

    if (bytes1 == null) {
      _setLoading(false);
      _setStatus('❌ First thumbnail generation failed');
      return;
    }

    // Second call — should use cache
    final stopwatch2 = Stopwatch()..start();
    final bytes2 = await FlutterWallpaperPlus.getVideoThumbnail(
      source: WallpaperSource.url(_sampleVideoUrl),
      quality: 50,
      cache: true,
    );
    stopwatch2.stop();

    _setLoading(false);

    if (bytes2 != null) {
      setState(() => _thumbnailBytes = bytes2);

      final speedup = stopwatch2.elapsedMilliseconds == 0
          ? 'instant'
          : '${(stopwatch1.elapsedMilliseconds / stopwatch2.elapsedMilliseconds).toStringAsFixed(1)}x';

      _setStatus(
        '✅ Thumbnail cache test\n'
        'First call: ${stopwatch1.elapsedMilliseconds}ms '
        '(${(bytes1.length / 1024).toStringAsFixed(1)} KB)\n'
        'Second call: ${stopwatch2.elapsedMilliseconds}ms (cached)\n'
        'Speedup: $speedup faster',
      );
    }
  }

  Future<void> _generateThumbnailLowQuality() async {
    _setLoading(true);
    _setStatus('Generating low quality thumbnail (q=10)...');

    final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
      source: WallpaperSource.url(_sampleVideoUrl),
      quality: 10,
      cache: false,
    );

    _setLoading(false);

    if (bytes != null) {
      setState(() => _thumbnailBytes = bytes);
      _setStatus(
        '✅ Low quality thumbnail\n'
        'Size: ${(bytes.length / 1024).toStringAsFixed(1)} KB (quality=10)',
      );
    } else {
      _setStatus('❌ Generation failed');
    }
  }

  Future<void> _generateThumbnailHighQuality() async {
    _setLoading(true);
    _setStatus('Generating high quality thumbnail (q=90)...');

    final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
      source: WallpaperSource.url(_sampleVideoUrl),
      quality: 90,
      cache: false,
    );

    _setLoading(false);

    if (bytes != null) {
      setState(() => _thumbnailBytes = bytes);
      _setStatus(
        '✅ High quality thumbnail\n'
        'Size: ${(bytes.length / 1024).toStringAsFixed(1)} KB (quality=90)',
      );
    } else {
      _setStatus('❌ Generation failed');
    }
  }

  void _clearThumbnail() {
    setState(() => _thumbnailBytes = null);
    _setStatus('Thumbnail cleared');
  }

  // ================================================================
  // Cache
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
    setState(() => _thumbnailBytes = null);
    _setStatus(result.success ? '✅ ${result.message}' : '❌ ${result.message}');
  }

  // ================================================================
  // Error Tests
  // ================================================================

  Future<void> _testBadUrl() async {
    _setLoading(true);
    _setStatus('Testing error handling...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url('https://invalid.example.com/nope.jpg'),
      target: WallpaperTarget.home,
      showToast: false,
    );

    _setLoading(false);
    _setStatus(
      '⚠️ ${result.message}\n'
      'Code: ${result.errorCode.name}\n'
      '(Intentional error test)',
    );
  }

  Future<void> _testCachePerformance() async {
    _setLoading(true);
    _setStatus('Cache performance test...');

    final sw1 = Stopwatch()..start();
    final r1 = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl),
      target: WallpaperTarget.home,
      showToast: false,
    );
    sw1.stop();

    if (!r1.success) {
      _setLoading(false);
      _setStatus('❌ ${r1.message}');
      return;
    }

    final sw2 = Stopwatch()..start();
    await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl),
      target: WallpaperTarget.home,
      showToast: false,
    );
    sw2.stop();

    _setLoading(false);

    final speedup = sw2.elapsedMilliseconds == 0
        ? 'instant'
        : '${(sw1.elapsedMilliseconds / sw2.elapsedMilliseconds).toStringAsFixed(1)}x';

    _setStatus(
      '✅ Cache performance\n'
      'Download: ${sw1.elapsedMilliseconds}ms\n'
      'Cached: ${sw2.elapsedMilliseconds}ms\n'
      'Speedup: $speedup',
    );
  }

  // ================================================================
  // Build
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpaper Plus — Phase 4'),
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
            // Status
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

            // Thumbnail preview
            if (_thumbnailBytes != null) ...[
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Image.memory(
                      _thumbnailBytes!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        onPressed: _clearThumbnail,
                        icon: const Icon(Icons.close, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Image Wallpaper
            _section(context, 'Image Wallpaper'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _setImageBoth,
              icon: const Icon(Icons.wallpaper),
              label: const Text('URL → Both Screens'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _setImageHome,
                    icon: const Icon(Icons.home),
                    label: const Text('Home'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _setImageLock,
                    icon: const Icon(Icons.lock),
                    label: const Text('Lock'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _setImageAsset,
              icon: const Icon(Icons.folder),
              label: const Text('Asset → Both Screens'),
            ),

            const SizedBox(height: 24),

            // Video Wallpaper
            _section(context, 'Video (Live) Wallpaper'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _setVideoSilentLoop,
              icon: const Icon(Icons.videocam),
              label: const Text('Silent + Loop'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _setVideoWithAudio,
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Audio'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _setVideoNoLoop,
                    icon: const Icon(Icons.replay),
                    label: const Text('No Loop'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Thumbnail Generation
            _section(context, 'Video Thumbnail'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateThumbnailFromUrl,
              icon: const Icon(Icons.image),
              label: const Text('Generate Thumbnail (q=50)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateThumbnailCached,
              icon: const Icon(Icons.cached),
              label: const Text('Cache Performance Test'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _generateThumbnailLowQuality,
                    icon: const Icon(Icons.compress),
                    label: const Text('q=10'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : _generateThumbnailHighQuality,
                    icon: const Icon(Icons.high_quality),
                    label: const Text('q=90'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Tests
            _section(context, 'Tests'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _testCachePerformance,
              icon: const Icon(Icons.speed),
              label: const Text('Image Cache Performance'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _testBadUrl,
              icon: const Icon(Icons.error_outline),
              label: const Text('Error Handling (Bad URL)'),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
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
