# Flutter Wallpaper Plus

[![pub package](https://img.shields.io/pub/v/flutter_wallpaper_plus.svg)](https://pub.dev/packages/flutter_wallpaper_plus)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Sanaullah49/flutter_wallpaper_plus/blob/main/LICENSE)
[![platform](https://img.shields.io/badge/platform-android-green.svg)](https://pub.dev/packages/flutter_wallpaper_plus)

Production-grade Flutter plugin for setting **image** and **video (live)** wallpapers on Android.

- Set wallpaper from **asset**, **file**, or **URL**
- Use **typed results** and **structured error codes**
- Generate and cache **video thumbnails**
- Manage cache with **size limits + LRU eviction**
- Handle OEM target limitations with `getTargetSupportPolicy()`

![Example App](screenshots/example_app.png)

## Table of Contents

- [Platform Support](#platform-support)
- [Installation](#installation)
- [Android Permissions](#android-permissions)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
- [Target Behavior and OEM Limitations](#target-behavior-and-oem-limitations)
- [FAQ](#faq)
- [Architecture](#architecture)
- [Roadmap](#roadmap)
- [License](#license)

## Platform Support

- Flutter: `>=3.3.0`
- Dart: `^3.11.0`
- Platform: **Android only**
- Android API: **24+**

| Capability | Android Support |
| --- | --- |
| Static image wallpaper | API 24+ |
| Live video wallpaper | API 24+ (device must support live wallpaper feature) |
| Video thumbnail generation | API 24+ |

## Installation

Add the package:

```yaml
dependencies:
  flutter_wallpaper_plus: ^1.0.0
```

Install dependencies:

```bash
flutter pub get
```

## Android Permissions

Permissions are declared by the plugin manifest:

```xml
<uses-permission android:name="android.permission.SET_WALLPAPER" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
```

Permission notes:

- `SET_WALLPAPER`, `INTERNET`, and `ACCESS_NETWORK_STATE` are normal permissions (auto-granted).
- Storage permissions are only needed for `WallpaperSource.file(...)` when reading outside app-internal storage.
- `WallpaperSource.asset(...)` and `WallpaperSource.url(...)` do not require storage read permission.

## Quick Start

Import once:

```dart
import 'package:flutter_wallpaper_plus/flutter_wallpaper_plus.dart';
```

### Set Image Wallpaper

```dart
final result = await FlutterWallpaperPlus.setImageWallpaper(
  source: WallpaperSource.url('https://example.com/wallpaper.jpg'),
  target: WallpaperTarget.home,
);

if (result.success) {
  print('Applied: ${result.message}');
} else {
  print('Failed: ${result.errorCode.name} - ${result.message}');
}
```

### Set Video (Live) Wallpaper

```dart
final result = await FlutterWallpaperPlus.setVideoWallpaper(
  source: WallpaperSource.url('https://example.com/live.mp4'),
  target: WallpaperTarget.home,
  enableAudio: false,
  loop: true,
);
```

Notes:

- Android opens the **system live wallpaper chooser** and user confirmation is required.
- `WallpaperTarget.lock` is not supported for live video wallpaper (`WallpaperErrorCode.unsupported`).
- Live wallpaper service runs independently after apply (survives app process death).

### Get Device Target Support Policy

Use this before rendering target options in UI:

```dart
final policy = await FlutterWallpaperPlus.getTargetSupportPolicy();

if (!policy.allowImageBoth) {
  // Disable "Image -> Both" action in UI
}
```

### Generate Video Thumbnail

```dart
final bytes = await FlutterWallpaperPlus.getVideoThumbnail(
  source: WallpaperSource.url('https://example.com/video.mp4'),
  quality: 50,
  cache: true,
);

if (bytes != null) {
  // Example: Image.memory(bytes)
}
```

### Cache Management

```dart
final size = await FlutterWallpaperPlus.getCacheSize();
print('Cache bytes: $size');

await FlutterWallpaperPlus.setMaxCacheSize(100 * 1024 * 1024); // 100 MB

final clearResult = await FlutterWallpaperPlus.clearCache();
print(clearResult.message);
```

## API Reference

### `FlutterWallpaperPlus`

| Method | Returns | Description |
| --- | --- | --- |
| `setImageWallpaper(...)` | `Future<WallpaperResult>` | Apply static image wallpaper |
| `setVideoWallpaper(...)` | `Future<WallpaperResult>` | Launch system chooser for live wallpaper |
| `getVideoThumbnail(...)` | `Future<Uint8List?>` | Extract video thumbnail bytes |
| `getTargetSupportPolicy()` | `Future<TargetSupportPolicy>` | Get device/OEM target reliability policy |
| `clearCache()` | `Future<WallpaperResult>` | Clear cached media + thumbnails |
| `getCacheSize()` | `Future<int>` | Read cache size in bytes |
| `setMaxCacheSize(int)` | `Future<void>` | Set max cache size (bytes) |

### `WallpaperSource`

| Constructor | Meaning |
| --- | --- |
| `WallpaperSource.asset(path)` | Flutter asset declared in `pubspec.yaml` |
| `WallpaperSource.file(path)` | Absolute file path on Android device |
| `WallpaperSource.url(url)` | Remote URL (downloaded and cached) |

### `WallpaperTarget`

| Value | Static image | Live video |
| --- | --- | --- |
| `home` | Supported | Supported |
| `lock` | Supported on compatible devices/OEMs | Unsupported by Android public APIs |
| `both` | Supported on compatible devices/OEMs | System chooser controlled; restricted on some OEMs |

### `WallpaperResult`

| Field | Type | Description |
| --- | --- | --- |
| `success` | `bool` | Operation success flag |
| `message` | `String` | Human-readable outcome |
| `errorCode` | `WallpaperErrorCode` | Structured code for handling |
| `isError` | `bool` | Convenience getter (`!success`) |

### `WallpaperErrorCode`

- `none`
- `sourceNotFound`
- `downloadFailed`
- `unsupported`
- `permissionDenied`
- `applyFailed`
- `videoError`
- `thumbnailFailed`
- `cacheFailed`
- `manufacturerRestriction`
- `unknown`

## Target Behavior and OEM Limitations

This section is important for product behavior and user expectations.

### Live Wallpaper Targeting Rules

- Live wallpaper always uses Android's native chooser flow.
- `WallpaperTarget.lock` for live video is unsupported on public Android APIs.
- Final behavior for live wallpapers can still be altered by OEM system apps/policies.

### Known OEM Restrictions

On some OEM ROMs (commonly Xiaomi/Redmi/Oppo/Vivo/Realme), lock-screen wallpaper behavior may be controlled by system policy (carousel/slideshow/theme engines). In these environments:

- Third-party apps may not reliably force lock wallpaper persistence.
- Lock/both behavior can diverge from what user selected in the system UI.
- The plugin may return `WallpaperErrorCode.manufacturerRestriction` for targets known to be unreliable.

There is currently **no reliable cross-OEM workaround** using public Android APIs.

### Recommended App-Side UX

- Query `getTargetSupportPolicy()` before showing target options.
- Disable unreliable target choices in your UI.
- Explain to users when device policy may override lock-screen wallpaper behavior.

## FAQ

### Does video wallpaper keep playing if the app is closed?

Yes. Playback is hosted in `WallpaperService` and is independent from your Flutter UI process.

### Why does video wallpaper open a system screen?

Android requires user confirmation for live wallpaper selection.

### Why does "Home only" sometimes affect lock screen?

Some OEMs mirror lock/home wallpaper behavior unless lock wallpaper is independently controlled by the ROM.

### Why does lock wallpaper revert after a few seconds on some devices?

Some ROM features (for example lock-screen slideshow/carousel) can override third-party lock wallpaper shortly after apply.

### What formats are supported?

- Video: device codec support via MediaCodec/ExoPlayer (MP4 H.264 recommended for best compatibility)
- Image: device-supported bitmap formats (JPEG/PNG/WebP/BMP, etc.)

## Architecture

```text
Flutter (Dart API)
  -> MethodChannel (com.flutterwallpaperplus/methods)
    -> Kotlin plugin layer
      -> ImageWallpaperManager
      -> VideoWallpaperService + ExoPlayer
      -> ThumbnailGenerator
      -> SourceResolver
      -> CacheManager (LRU)
      -> PermissionHelper
```

## Roadmap

Planned next additions:

- Open native wallpaper chooser API for user-driven apply flow
- Optional "minimize app and go to Home" helper/check for smoother apply UX

## License

MIT. See [LICENSE](LICENSE).
