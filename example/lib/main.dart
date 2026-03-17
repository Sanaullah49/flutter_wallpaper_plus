import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_wallpaper_plus/flutter_wallpaper_plus.dart';

void main() {
  debugPrint('[ExampleDart] main()');
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
  bool _goHomeBeforeChooser = false;
  WallpaperTarget _autoChangeTarget = WallpaperTarget.home;
  final TextEditingController _autoChangeIntervalController =
      TextEditingController(text: '1');
  WallpaperAutoChangeStatus _autoChangeStatus =
      const WallpaperAutoChangeStatus.stopped();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _loadTargetPolicy();
    _refreshAutoChangeStatus(showBusy: false);
    debugPrint('[ExampleDart] HomePage initState');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _autoChangeIntervalController.dispose();
    debugPrint('[ExampleDart] HomePage dispose');
    super.dispose();
  }

  final _lifecycleObserver = _ExampleLifecycleObserver();

  Future<void> _loadTargetPolicy() async {
    final policy = await FlutterWallpaperPlus.getTargetSupportPolicy();
    if (!mounted) return;
    if (policy.restrictiveOem) {
      _updateStatus(
        '⚠️ ${policy.manufacturer} policy detected: lock/both targets '
        'may still vary by ROM behavior.',
      );
    }
  }

  // ================================================================
  // Sample URLs — replace with your own for testing
  // ================================================================

  static const _imageUrl1 =
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb'
      '?w=1080&q=80';

  static const _imageUrl2 =
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05'
      '?w=1080&q=80';

  static const _autoChangeImage1 =
      'https://dummyimage.com/1080x1920/ff6b6b/ffffff.jpg&text=Auto+Change+1';

  static const _autoChangeImage2 =
      'https://dummyimage.com/1080x1920/4ecdc4/0b1f2a.jpg&text=Auto+Change+2';

  static const _autoChangeImage3 =
      'https://dummyimage.com/1080x1920/1a73e8/ffffff.jpg&text=Auto+Change+3';

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

  int get _autoChangeIntervalMinutes {
    final parsed = int.tryParse(_autoChangeIntervalController.text.trim());
    return parsed ?? 1;
  }

  List<WallpaperSource> get _autoChangeSources => [
    WallpaperSource.url(_autoChangeImage1),
    WallpaperSource.url(_autoChangeImage2),
    WallpaperSource.url(_autoChangeImage3),
  ];

  String get _autoChangeStatusText {
    final status = _autoChangeStatus;
    final nextRun = status.nextRunAt;
    final nextRunText = nextRun == null
        ? 'Not scheduled'
        : '${nextRun.hour.toString().padLeft(2, '0')}:'
              '${nextRun.minute.toString().padLeft(2, '0')}:'
              '${nextRun.second.toString().padLeft(2, '0')}';

    return 'Running: ${status.isRunning ? 'Yes' : 'No'}\n'
        'Target: ${status.target.name}\n'
        'Interval: ${status.intervalMinutes} min\n'
        'Playlist: ${status.totalCount} wallpapers\n'
        'Next index: ${status.nextIndex}\n'
        'Next run: $nextRunText\n'
        'Last error: ${status.lastError ?? 'None'}';
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
  // Auto Change Actions
  // ================================================================

  Future<void> _refreshAutoChangeStatus({bool showBusy = true}) async {
    if (showBusy) {
      _loading(true);
    }

    try {
      final status = await FlutterWallpaperPlus.getWallpaperAutoChangeStatus();
      if (!mounted) return;

      setState(() => _autoChangeStatus = status);
      _updateStatus('ℹ️ Auto Change status refreshed');
    } catch (e) {
      _updateStatus('❌ Failed to load Auto Change status: $e');
    } finally {
      if (showBusy) {
        _loading(false);
      }
    }
  }

  Future<void> _startAutoChange() => _run('Auto Change → Start', () async {
    final result = await FlutterWallpaperPlus.startWallpaperAutoChange(
      sources: _autoChangeSources,
      target: _autoChangeTarget,
      interval: Duration(minutes: _autoChangeIntervalMinutes),
      successMessage: 'Wallpaper Auto Change started',
      errorMessage: 'Failed to start Wallpaper Auto Change',
    );

    _showResult(result);
    await _refreshAutoChangeStatus(showBusy: false);
  });

  Future<void> _applyNextAutoChangeNow() =>
      _run('Auto Change → Apply next now', () async {
        final result = await FlutterWallpaperPlus.applyNextWallpaperNow(
          successMessage: 'Applied next Auto Change wallpaper',
          errorMessage: 'Failed to apply next Auto Change wallpaper',
        );

        _showResult(result);
        await _refreshAutoChangeStatus(showBusy: false);
      });

  Future<void> _stopAutoChange() => _run('Auto Change → Stop', () async {
    final result = await FlutterWallpaperPlus.stopWallpaperAutoChange(
      successMessage: 'Wallpaper Auto Change stopped',
      errorMessage: 'Failed to stop Wallpaper Auto Change',
    );

    _showResult(result);
    await _refreshAutoChangeStatus(showBusy: false);
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

  Future<void> _videoSilentLoopBoth() =>
      _run('Video (silent, loop, both)', () async {
        _showResult(
          await FlutterWallpaperPlus.setVideoWallpaper(
            source: WallpaperSource.url(_videoUrl),
            target: WallpaperTarget.both,
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
  // Native Chooser
  // ================================================================

  Future<void> _openNativeWallpaperChooser() =>
      _run('Open native chooser', () async {
        _showResult(
          await FlutterWallpaperPlus.openNativeWallpaperChooser(
            source: WallpaperSource.url(_imageUrl1),
            goToHome: _goHomeBeforeChooser,
            successMessage: 'Native wallpaper chooser opened',
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
    debugPrint('[ExampleDart] HomePage build');
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
          // Note: Lock/both targets now work on restrictive OEMs (Xiaomi, Oppo, Vivo, Realme)
          // thanks to sequential writes with delays, matching async_wallpaper behavior
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

          // Auto Change
          _header('Wallpaper Auto Change'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick verification',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Uses 3 bold sample wallpapers so you can quickly confirm '
                    'home, lock, or both target behavior.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('Target', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<WallpaperTarget>(
                    segments: const [
                      ButtonSegment(
                        value: WallpaperTarget.home,
                        label: Text('Home'),
                        icon: Icon(Icons.home_outlined),
                      ),
                      ButtonSegment(
                        value: WallpaperTarget.lock,
                        label: Text('Lock'),
                        icon: Icon(Icons.lock_outline),
                      ),
                      ButtonSegment(
                        value: WallpaperTarget.both,
                        label: Text('Both'),
                        icon: Icon(Icons.smartphone_outlined),
                      ),
                    ],
                    selected: {_autoChangeTarget},
                    onSelectionChanged: _isLoading
                        ? null
                        : (selection) => setState(
                            () => _autoChangeTarget = selection.first,
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _autoChangeIntervalController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Interval (minutes)',
                      helperText:
                          'Minimum 1 minute. Background timing is best-effort.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _autoChangeStatusText,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _btn(
                        Icons.play_arrow_outlined,
                        'Start',
                        _startAutoChange,
                      ),
                      _outlineBtn(
                        Icons.refresh_outlined,
                        'Refresh Status',
                        () => _refreshAutoChangeStatus(),
                      ),
                      _outlineBtn(
                        Icons.skip_next_outlined,
                        'Apply Next Now',
                        _applyNextAutoChangeNow,
                      ),
                      _outlineBtn(
                        Icons.stop_circle_outlined,
                        'Stop',
                        _stopAutoChange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Video Wallpaper
          _header('Video (Live) Wallpaper'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _btn(
                  Icons.home_outlined,
                  'Silent + Loop (Home)',
                  _videoSilentLoop,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _btn(
                  Icons.smartphone_outlined,
                  'Silent + Loop (Both)',
                  _videoSilentLoopBoth,
                ),
              ),
            ],
          ),
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

          // Native Chooser
          _header('Native Wallpaper Chooser'),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Minimize app and go home first'),
            subtitle: const Text(
              'Best-effort behavior before opening the native chooser.',
            ),
            value: _goHomeBeforeChooser,
            onChanged: _isLoading
                ? null
                : (value) => setState(() => _goHomeBeforeChooser = value),
          ),
          const SizedBox(height: 8),
          _btn(
            Icons.wallpaper_outlined,
            'Open Native Wallpaper Chooser',
            _openNativeWallpaperChooser,
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

class _ExampleLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[ExampleDart] AppLifecycleState: $state');
  }
}
