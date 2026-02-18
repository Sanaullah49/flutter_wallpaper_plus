# Flutter Wallpaper Plus

[![pub package](https://img.shields.io/pub/v/flutter_wallpaper_plus.svg)](https://pub.dev/packages/flutter_wallpaper_plus)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/yourorg/flutter_wallpaper_plus/blob/main/LICENSE)
[![platform](https://img.shields.io/badge/platform-android-green.svg)]()
[![tests](https://img.shields.io/badge/tests-90%2B%20passing-brightgreen.svg)]()

Production-grade Flutter plugin for setting **image** and **video (live) wallpapers** on Android with caching, thumbnails, and structured error handling.

---

## Features

| Feature | Description |
|---------|-------------|
| 🖼️ **Image Wallpaper** | Set from asset, file, or URL |
| 🎬 **Video Wallpaper** | Live wallpaper with ExoPlayer |
| 🏠 **Target Control** | Home screen, lock screen, or both |
| 🔊 **Audio Control** | Enable/disable audio for video wallpapers |
| 🔁 **Seamless Loop** | Loop video wallpapers with no gap |
| 💀 **Survives App Kill** | Video wallpaper runs as independent service |
| 📐 **Rotation Safe** | Handles screen rotation without crashing |
| 🔋 **Battery Efficient** | Pauses video when not visible |
| 🖼️ **Thumbnails** | Extract video thumbnails with quality control |
| 💾 **Smart Caching** | LRU cache with configurable size limit |
| 📱 **Toast Messages** | Optional Android toasts with custom messages |
| ✅ **Structured Errors** | Every operation returns typed error codes |
| 🔒 **Permission Aware** | Handles Android 7–14 permission models |

## Supported Android Versions

| API Level | Android Version | Image Wallpaper | Video Wallpaper | Thumbnails |
|-----------|-----------------|:-:|:-:|:-:|
| 24        | 7.0 Nougat      | ✅ | ✅ | ✅ |
| 26        | 8.0 Oreo        | ✅ | ✅ | ✅ |
| 29        | 10              | ✅ | ✅ | ✅ |
| 31        | 12              | ✅ | ✅ | ✅ |
| 33        | 13              | ✅ | ✅ | ✅ |
| 34        | 14              | ✅ | ✅ | ✅ |
| 35        | 15              | ✅ | ✅ | ✅ |
| 36        | 16              | ✅ | ✅ | ✅ |

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_wallpaper_plus: ^1.0.0

Then run:

Bash

flutter pub get
Android Permissions
The plugin declares these permissions automatically:

XML

<!-- Auto-granted (normal permissions) -->
<uses-permission android:name="android.permission.SET_WALLPAPER" />
<uses-permission android:name="android.permission.INTERNET" />

<!-- Only needed for WallpaperSource.file() with external paths -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
Note: SET_WALLPAPER and INTERNET are normal permissions — auto-granted at install. Storage permissions are only needed if you use WallpaperSource.file() with paths outside your app's directory. Assets and URLs don't require storage permissions.

Quick Start
dart

import 'package:flutter_wallpaper_plus/flutter_wallpaper_plus.dart';
Set Image Wallpaper
dart

// From URL
final result = await FlutterWallpaperPlus.setImageWallpaper(
  source: WallpaperSource.url('https://example.com/wallpaper.jpg'),
  target: WallpaperTarget.both,
);

// From asset
final result = await FlutterWallpaperPlus.setImageWallpaper(
  source: WallpaperSource.asset('assets/nature.jpg'),
  target: WallpaperTarget.home,
);

// From file
final result = await FlutterWallpaperPlus.setImageWallpaper(
  source: WallpaperSource.file('/storage/emulated/0/Download/bg.jpg'),
  target: WallpaperTarget.lock,
);

// Check result
if (result.success) {
  print('Wallpaper applied!');
} else {
  print('Error: ${result.errorCode} — ${result.message}');
}
Set Video (Live) Wallpaper
dart

final result = await FlutterWallpaperPlus.setVideoWallpaper(
  source: WallpaperSource.url('https://example.com/live-bg.mp4'),
  target: WallpaperTarget.home,
  enableAudio: false,
  loop: true,
);
The system wallpaper picker will open for user confirmation. The video wallpaper service runs independently and survives app kill.

Generate Video Thumbnail
dart

final Uint8List? thumbnail = await FlutterWallpaperPlus.getVideoThumbnail(
  source: WallpaperSource.url('https://example.com/video.mp4'),
  quality: 50,  // JPEG quality 1-100
  cache: true,  // Cache for instant subsequent calls
);

if (thumbnail != null) {
  // Display it
  Image.memory(thumbnail);
}
Cache Management
dart

// Get cache size
final bytes = await FlutterWallpaperPlus.getCacheSize();
print('Cache: ${(bytes / 1024 / 1024).toStringAsFixed(2)} MB');

// Clear all cached files
final result = await FlutterWallpaperPlus.clearCache();

// Set maximum cache size (default: 200 MB)
await FlutterWallpaperPlus.setMaxCacheSize(100 * 1024 * 1024); // 100 MB
API Reference
FlutterWallpaperPlus
Method	Returns	Description
setImageWallpaper()	Future<WallpaperResult>	Set static image wallpaper
setVideoWallpaper()	Future<WallpaperResult>	Set video live wallpaper
getVideoThumbnail()	Future<Uint8List?>	Extract video thumbnail
clearCache()	Future<WallpaperResult>	Clear all cached files
getCacheSize()	Future<int>	Get total cache size in bytes
setMaxCacheSize()	Future<void>	Configure max cache size
WallpaperSource
Constructor	Description
WallpaperSource.asset(path)	Flutter asset from pubspec.yaml
WallpaperSource.file(path)	Absolute file path on device
WallpaperSource.url(url)	Remote URL (downloaded & cached)
WallpaperTarget
Value	Description
WallpaperTarget.home	Home screen only
WallpaperTarget.lock	Lock screen only
WallpaperTarget.both	Both screens
WallpaperResult
Property	Type	Description
success	bool	Whether the operation succeeded
message	String	Human-readable description
errorCode	WallpaperErrorCode	Structured error code
isError	bool	Convenience: !success
WallpaperErrorCode
Code	Description
none	No error (success)
sourceNotFound	Asset/file/URL not found
downloadFailed	Network error downloading URL
unsupported	Feature not supported on device
permissionDenied	Required permission not granted
applyFailed	WallpaperManager failed to apply
videoError	Video playback/decoding error
thumbnailFailed	Thumbnail extraction failed
cacheFailed	Cache operation failed
manufacturerRestriction	OEM/MDM policy blocks operation
unknown	Unexpected error
Custom Toast Messages
dart

final result = await FlutterWallpaperPlus.setImageWallpaper(
  source: WallpaperSource.url('https://example.com/bg.jpg'),
  target: WallpaperTarget.both,
  successMessage: 'Beautiful wallpaper applied! 🎨',
  errorMessage: 'Oops, something went wrong',
  showToast: true,  // Set to false to handle UI yourself
);
Error Handling
Every method returns structured results — no try/catch needed for operational errors:

dart

final result = await FlutterWallpaperPlus.setImageWallpaper(
  source: WallpaperSource.url('https://example.com/bg.jpg'),
  target: WallpaperTarget.home,
);

switch (result.errorCode) {
  case WallpaperErrorCode.none:
    // Success!
    break;
  case WallpaperErrorCode.downloadFailed:
    // Show retry button
    break;
  case WallpaperErrorCode.permissionDenied:
    // Request permission
    break;
  case WallpaperErrorCode.unsupported:
    // Feature not available on this device
    break;
  case WallpaperErrorCode.manufacturerRestriction:
    // OEM restriction — show explanation
    break;
  default:
    // Handle other cases
    break;
}
Architecture
text

┌─────────────────────────────────────────────┐
│                 Dart Layer                   │
│  FlutterWallpaperPlus (public API)          │
│  └─ FlutterWallpaperPlusImpl (channel)      │
├─────────────────────────────────────────────┤
│              MethodChannel                   │
├─────────────────────────────────────────────┤
│              Kotlin Layer                    │
│  FlutterWallpaperPlusPlugin (entry point)   │
│  └─ WallpaperMethodHandler (routing)        │
│      ├─ ImageWallpaperManager               │
│      ├─ VideoWallpaperService               │
│      │   └─ VideoRenderer (ExoPlayer)       │
│      ├─ ThumbnailGenerator                  │
│      ├─ SourceResolver                      │
│      ├─ CacheManager (LRU)                  │
│      └─ PermissionHelper                    │
└─────────────────────────────────────────────┘
FAQ
Q: Does the video wallpaper keep playing after I close the app?
A: Yes. The VideoWallpaperService runs independently as an Android service. It survives app kill and device restart.

Q: Does the video wallpaper drain battery?
A: The service automatically pauses playback when the wallpaper is not visible (when an app is in the foreground) and resumes when the home screen is shown.

Q: What video formats are supported?
A: Any format supported by Android's MediaCodec / ExoPlayer: MP4 (H.264/H.265), WebM (VP8/VP9), MKV, 3GP. MP4 with H.264 is recommended for maximum compatibility.

Q: What image formats are supported?
A: JPEG, PNG, WebP, BMP, GIF (first frame only).

Q: Why does setVideoWallpaper open a system dialog?
A: Android requires user confirmation before setting a live wallpaper. This is a security requirement enforced by the OS and cannot be bypassed.

Q: What happens if the cached video file is deleted?
A: The VideoWallpaperService checks file existence when the surface is created. If the file is missing, the wallpaper shows a blank surface. The user would need to set the wallpaper again.

License
MIT License — see LICENSE for details.