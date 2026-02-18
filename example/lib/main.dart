import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_wallpaper_plus/flutter_wallpaper_plus.dart';

void main() {
  runApp(const WallpaperPlusExample());
}

class WallpaperPlusExample extends StatelessWidget {
  const WallpaperPlusExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper Plus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
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
  String _status = 'Ready';
  bool _isLoading = false;
  Uint8List? _thumbnailBytes;

  // ================================================================
  // Sample URLs — replace with your own for testing
  // ================================================================

  static const _imageUrl1 =
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb'
      '?w=1080&q=80';

  static const _imageUrl2 =
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05'
      '?w=1080&q=80';

  static const _videoUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/'
      'sample/ForBiggerBlazes.mp4';

  // ================================================================
  // Helpers
  // ================================================================

  void _updateStatus(String status) {
    if (mounted) setState(() => _status = status);
  }

  void _loading(bool value) {
    if (mounted) setState(() => _isLoading = value);
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    _loading(true);
    _updateStatus('$label...');
    try {
      await action();
    } catch (e) {
      _updateStatus('❌ Unexpected: $e');
    }
    _loading(false);
  }

  void _showResult(WallpaperResult result) {
    _updateStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\nCode: ${result.errorCode.name}',
    );
  }

  // ================================================================
  // Image Wallpaper Actions
  // ================================================================

  Future<void> _imageUrlBoth() => _run('Image → Both', () async {
    _showResult(
      await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url(_imageUrl1),
        target: WallpaperTarget.both,
        successMessage: 'Wallpaper applied to both screens!',
      ),
    );
  });

  Future<void> _imageUrlHome() => _run('Image → Home', () async {
    _showResult(
      await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url(_imageUrl2),
        target: WallpaperTarget.home,
      ),
    );
  });

  Future<void> _imageUrlLock() => _run('Image → Lock', () async {
    _showResult(
      await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.url(_imageUrl1),
        target: WallpaperTarget.lock,
      ),
    );
  });

  Future<void> _imageAsset() => _run('Image Asset', () async {
    _showResult(
      await FlutterWallpaperPlus.setImageWallpaper(
        source: WallpaperSource.asset('assets/sample_wallpaper.jpg'),
        target: WallpaperTarget.both,
      ),
    );
  });

  // ================================================================
  // Video Wallpaper Actions
  // ================================================================

  Future<void> _videoSilentLoop() => _run('Video (silent, loop)', () async {
    _showResult(
      await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url(_videoUrl),
        target: WallpaperTarget.home,
        enableAudio: false,
        loop: true,
        successMessage: 'Video wallpaper ready — confirm in picker!',
      ),
    );
  });

  Future<void> _videoAudioLoop() => _run('Video (audio, loop)', () async {
    _showResult(
      await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url(_videoUrl),
        target: WallpaperTarget.home,
        enableAudio: true,
        loop: true,
      ),
    );
  });

  Future<void> _videoNoLoop() => _run('Video (no loop)', () async {
    _showResult(
      await FlutterWallpaperPlus.setVideoWallpaper(
        source: WallpaperSource.url(_videoUrl),
        target: WallpaperTarget.home,
        enableAudio: false,
        loop: false,
      ),
    );
  });

  // ================================================================
  // Thumbnail Actions
  // ================================================================

  Future<void> _thumbnailDefault() => _run('Thumbnail (q=50)', () async {
    final sw = Stopwatch()..start();
    final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
      source: WallpaperSource.url(_videoUrl),
      quality: 50,
    );
    sw.stop();

    if (bytes != null) {
      setState(() => _thumbnailBytes = bytes);
      _updateStatus(
        '✅ Thumbnail: ${(bytes.length / 1024).toStringAsFixed(1)} KB'
        ' in ${sw.elapsedMilliseconds}ms',
      );
    } else {
      _updateStatus('❌ Thumbnail generation failed');
    }
  });

  Future<void> _thumbnailCacheTest() => _run('Thumbnail cache', () async {
    final sw1 = Stopwatch()..start();
    final b1 = await FlutterWallpaperPlus.getVideoThumbnail(
      source: WallpaperSource.url(_videoUrl),
      quality: 50,
    );
    sw1.stop();

    if (b1 == null) {
      _updateStatus('❌ First call failed');
      return;
    }

    final sw2 = Stopwatch()..start();
    final b2 = await FlutterWallpaperPlus.getVideoThumbnail(
      source: WallpaperSource.url(_videoUrl),
      quality: 50,
    );
    sw2.stop();

    if (b2 != null) setState(() => _thumbnailBytes = b2);

    final speed = sw2.elapsedMilliseconds == 0
        ? 'instant'
        : '${(sw1.elapsedMilliseconds / sw2.elapsedMilliseconds).toStringAsFixed(1)}x';

    _updateStatus(
      '✅ Cache test\n'
      '1st: ${sw1.elapsedMilliseconds}ms | '
      '2nd: ${sw2.elapsedMilliseconds}ms | '
      'Speedup: $speed',
    );
  });

  Future<void> _thumbnailLow() => _run('Thumbnail (q=10)', () async {
    final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
      source: WallpaperSource.url(_videoUrl),
      quality: 10,
      cache: false,
    );
    if (bytes != null) {
      setState(() => _thumbnailBytes = bytes);
      _updateStatus(
        '✅ Low quality: ${(bytes.length / 1024).toStringAsFixed(1)} KB',
      );
    }
  });

  Future<void> _thumbnailHigh() => _run('Thumbnail (q=90)', () async {
    final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
      source: WallpaperSource.url(_videoUrl),
      quality: 90,
      cache: false,
    );
    if (bytes != null) {
      setState(() => _thumbnailBytes = bytes);
      _updateStatus(
        '✅ High quality: ${(bytes.length / 1024).toStringAsFixed(1)} KB',
      );
    }
  });

  // ================================================================
  // Cache Actions
  // ================================================================

  Future<void> _cacheSize() async {
    final size = await FlutterWallpaperPlus.getCacheSize();
    _updateStatus(
      '📦 Cache: ${(size / 1024 / 1024).toStringAsFixed(2)} MB ($size B)',
    );
  }

  Future<void> _cacheClear() => _run('Clear cache', () async {
    final r = await FlutterWallpaperPlus.clearCache();
    setState(() => _thumbnailBytes = null);
    _showResult(r);
  });

  // ================================================================
  // Error Test
  // ================================================================

  Future<void> _testError() => _run('Error test', () async {
    final r = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url('https://invalid.test/nope.jpg'),
      target: WallpaperTarget.home,
      showToast: false,
    );
    _updateStatus(
      '⚠️ ${r.message}\nCode: ${r.errorCode.name}\n(Intentional test)',
    );
  });

  // ================================================================
  // Build
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Wallpaper Plus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage_outlined),
            tooltip: 'Cache size',
            onPressed: _cacheSize,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear cache',
            onPressed: _isLoading ? null : _cacheClear,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(),
                    ),
                  Text(
                    _status,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Thumbnail preview
          if (_thumbnailBytes != null) ...[
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Image.memory(
                    _thumbnailBytes!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                      onPressed: () => setState(() => _thumbnailBytes = null),
                      icon: const Icon(Icons.close, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Image Wallpaper
          _header('Image Wallpaper'),
          const SizedBox(height: 8),
          _btn(Icons.wallpaper, 'URL → Both Screens', _imageUrlBoth),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _btn(Icons.home_outlined, 'Home', _imageUrlHome)),
              const SizedBox(width: 8),
              Expanded(child: _btn(Icons.lock_outline, 'Lock', _imageUrlLock)),
            ],
          ),
          const SizedBox(height: 8),
          _btn(Icons.folder_outlined, 'Asset → Both', _imageAsset),

          const SizedBox(height: 20),

          // Video Wallpaper
          _header('Video (Live) Wallpaper'),
          const SizedBox(height: 8),
          _btn(Icons.videocam_outlined, 'Silent + Loop', _videoSilentLoop),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _btn(Icons.volume_up_outlined, 'Audio', _videoAudioLoop),
              ),
              const SizedBox(width: 8),
              Expanded(child: _btn(Icons.replay, 'No Loop', _videoNoLoop)),
            ],
          ),

          const SizedBox(height: 20),

          // Thumbnails
          _header('Video Thumbnails'),
          const SizedBox(height: 8),
          _btn(Icons.image_outlined, 'Generate (q=50)', _thumbnailDefault),
          const SizedBox(height: 8),
          _btn(Icons.cached, 'Cache Performance', _thumbnailCacheTest),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _outlineBtn(Icons.compress, 'q=10', _thumbnailLow),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _outlineBtn(
                  Icons.high_quality_outlined,
                  'q=90',
                  _thumbnailHigh,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Tests
          _header('Tests'),
          const SizedBox(height: 8),
          _outlineBtn(
            Icons.error_outline,
            'Error Handling (Bad URL)',
            _testError,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _header(String text) {
    return Row(
      children: [
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _outlineBtn(IconData icon, String label, VoidCallback? onPressed) {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
