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

  // Sample URLs — replace with your own for testing
  static const _sampleImageUrl =
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb'
      '?w=1080&q=80';

  static const _sampleImageUrl2 =
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05'
      '?w=1080&q=80';

  // Sample video URL — use a short mp4 for testing
  // Replace with your own video URL
  static const _sampleVideoUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/'
      'sample/ForBiggerBlazes.mp4';

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
  // Image Wallpaper
  // ================================================================

  Future<void> _setImageFromUrlBoth() async {
    _setLoading(true);
    _setStatus('Downloading and setting wallpaper (both screens)...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl),
      target: WallpaperTarget.both,
      successMessage: 'Nature wallpaper applied to both screens!',
      errorMessage: 'Could not set wallpaper',
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

  Future<void> _setVideoWallpaperFromUrl() async {
    _setLoading(true);
    _setStatus('Downloading video and preparing live wallpaper...');

    final result = await FlutterWallpaperPlus.setVideoWallpaper(
      source: WallpaperSource.url(_sampleVideoUrl),
      target: WallpaperTarget.home,
      enableAudio: false,
      loop: true,
      successMessage: 'Video wallpaper ready — please confirm!',
      errorMessage: 'Could not set video wallpaper',
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _setVideoWallpaperWithAudio() async {
    _setLoading(true);
    _setStatus('Preparing video wallpaper with audio...');

    final result = await FlutterWallpaperPlus.setVideoWallpaper(
      source: WallpaperSource.url(_sampleVideoUrl),
      target: WallpaperTarget.home,
      enableAudio: true,
      loop: true,
      successMessage: 'Video wallpaper with audio ready!',
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _setVideoWallpaperNoLoop() async {
    _setLoading(true);
    _setStatus('Preparing video wallpaper (no loop)...');

    final result = await FlutterWallpaperPlus.setVideoWallpaper(
      source: WallpaperSource.url(_sampleVideoUrl),
      target: WallpaperTarget.home,
      enableAudio: false,
      loop: false,
      successMessage: 'Video wallpaper (single play) ready!',
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  Future<void> _setVideoWallpaperFromAsset() async {
    _setLoading(true);
    _setStatus('Setting video wallpaper from asset...');

    // Note: You need to add a sample .mp4 to example/assets/ for this to work
    final result = await FlutterWallpaperPlus.setVideoWallpaper(
      source: WallpaperSource.asset('assets/sample_video.mp4'),
      target: WallpaperTarget.home,
      enableAudio: false,
      loop: true,
      successMessage: 'Asset video wallpaper ready!',
    );

    _setLoading(false);
    _setStatus(
      result.success
          ? '✅ ${result.message}'
          : '❌ ${result.message}\n(${result.errorCode.name})',
    );
  }

  // ================================================================
  // Error Handling Tests
  // ================================================================

  Future<void> _testInvalidUrl() async {
    _setLoading(true);
    _setStatus('Testing error handling (bad URL)...');

    final result = await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(
        'https://invalid.example.com/nonexistent.jpg',
      ),
      target: WallpaperTarget.home,
      showToast: false,
    );

    _setLoading(false);
    _setStatus(
      '⚠️ ${result.message}\n'
      'Error code: ${result.errorCode.name}\n'
      '(This error was intentional)',
    );
  }

  Future<void> _testCachePerformance() async {
    _setLoading(true);
    _setStatus('First call: downloading...');

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

    _setStatus('Second call: using cache...');

    final stopwatch2 = Stopwatch()..start();
    await FlutterWallpaperPlus.setImageWallpaper(
      source: WallpaperSource.url(_sampleImageUrl),
      target: WallpaperTarget.home,
      showToast: false,
    );
    stopwatch2.stop();

    _setLoading(false);

    final speedup = stopwatch2.elapsedMilliseconds == 0
        ? 'instant'
        : '${(stopwatch1.elapsedMilliseconds / stopwatch2.elapsedMilliseconds).toStringAsFixed(1)}x';

    _setStatus(
      '✅ Cache performance test\n'
      'First call (download): ${stopwatch1.elapsedMilliseconds}ms\n'
      'Second call (cached): ${stopwatch2.elapsedMilliseconds}ms\n'
      'Speedup: $speedup faster',
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
        title: const Text('Wallpaper Plus — Phase 3'),
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

            // --- Image Wallpaper ---
            _sectionHeader(context, 'Image Wallpaper — URL'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _setImageFromUrlBoth,
              icon: const Icon(Icons.wallpaper),
              label: const Text('URL → Both Screens'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _setImageFromUrlHome,
                    icon: const Icon(Icons.home),
                    label: const Text('Home'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _setImageFromUrlLock,
                    icon: const Icon(Icons.lock),
                    label: const Text('Lock'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _setImageFromAsset,
              icon: const Icon(Icons.folder),
              label: const Text('Asset → Both Screens'),
            ),

            const SizedBox(height: 24),

            // --- Video Wallpaper ---
            _sectionHeader(context, 'Video (Live) Wallpaper'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _setVideoWallpaperFromUrl,
              icon: const Icon(Icons.videocam),
              label: const Text('Video URL — No Audio, Loop'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _setVideoWallpaperWithAudio,
              icon: const Icon(Icons.volume_up),
              label: const Text('Video URL — With Audio, Loop'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _setVideoWallpaperNoLoop,
              icon: const Icon(Icons.replay),
              label: const Text('Video URL — No Audio, No Loop'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _setVideoWallpaperFromAsset,
              icon: const Icon(Icons.folder_special),
              label: const Text('Video Asset (needs sample_video.mp4)'),
            ),

            const SizedBox(height: 24),

            // --- Tests ---
            _sectionHeader(context, 'Tests'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _testCachePerformance,
              icon: const Icon(Icons.speed),
              label: const Text('Cache Performance Test'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _testInvalidUrl,
              icon: const Icon(Icons.error_outline),
              label: const Text('Test Error Handling (Bad URL)'),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
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
