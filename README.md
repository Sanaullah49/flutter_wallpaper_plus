# Flutter Wallpaper Plus

[![Phase](https://img.shields.io/badge/phase-1%20of%205-blue)]()
[![Platform](https://img.shields.io/badge/platform-android-green)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()

Production-grade Flutter plugin for setting image and video (live) wallpapers on Android.

## 🚧 Work in Progress

This plugin is being built in 5 phases:

- [x] **Phase 1** — Foundation (Dart API, caching, source resolution, permissions)
- [ ] **Phase 2** — Image wallpaper implementation
- [ ] **Phase 3** — Video (live) wallpaper implementation
- [ ] **Phase 4** — Thumbnail generation
- [ ] **Phase 5** — Polish, testing, publish

## Planned Features

- ✅ Image wallpaper (asset, file, URL)
- ✅ Video live wallpaper with ExoPlayer
- ✅ Home screen, lock screen, or both
- ✅ Audio enable/disable for video
- ✅ Seamless looping
- ✅ Survives app kill and rotation
- ✅ Video thumbnail generation
- ✅ Intelligent LRU caching
- ✅ Structured error handling
- ✅ Custom toast messages
- ✅ Android 7.0+ (API 24+) support

## API Preview

```dart
import 'package:flutter_wallpaper_plus/flutter_wallpaper_plus.dart';

// Image wallpaper
final result = await FlutterWallpaperPlus.setImageWallpaper(
  source: WallpaperSource.url('https://example.com/bg.jpg'),
  target: WallpaperTarget.both,
);

// Video wallpaper
final result = await FlutterWallpaperPlus.setVideoWallpaper(
  source: WallpaperSource.asset('assets/rain.mp4'),
  target: WallpaperTarget.home,
  enableAudio: false,
  loop: true,
);

// Thumbnail
final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
  source: WallpaperSource.url('https://example.com/video.mp4'),
);

// Cache management
await FlutterWallpaperPlus.clearCache();
final size = await FlutterWallpaperPlus.getCacheSize();
await FlutterWallpaperPlus.setMaxCacheSize(100 * 1024 * 1024);