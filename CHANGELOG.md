# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-02-18

### Changed
- Android live wallpaper service label now inherits the host app label, so the picker shows the app name instead of a hardcoded "Video Wallpaper" label.

### Fixed
- Android example app no longer goes black/white after wallpaper apply on OEMs that recreate the activity (e.g., MIUI): `MainActivity` now reuses a cached `FlutterEngine` across host activity recreation.

### Added

#### Image Wallpaper
- Set image wallpaper from Flutter asset, local file, or remote URL
- Target home screen, lock screen, or both
- Memory-efficient streaming via `WallpaperManager.setStream()`
- Pre-flight checks: `isWallpaperSupported`, `isSetWallpaperAllowed`

#### Video (Live) Wallpaper
- Set video wallpaper using Android's `WallpaperService` + Media3 ExoPlayer
- Enable/disable audio at runtime
- Seamless looping via `Player.REPEAT_MODE_ALL`
- Survives app kill (config persisted in `SharedPreferences`)
- Handles screen rotation without crashing
- Pauses when not visible, resumes on home screen (battery saving)
- Automatic error recovery (seek to start + re-prepare)
- Two-strategy intent launch (direct component → fallback picker)

#### Thumbnail Generation
- Extract video thumbnails using `MediaMetadataRetriever`
- 3-level frame extraction fallback strategy
- Proportional scaling to max 480px dimension
- JPEG compression with configurable quality (1–100)
- Optional thumbnail caching for instant subsequent calls
- Explicit `Bitmap` recycling for memory efficiency

#### Caching System
- SHA-256 filename hashing for collision-resistant cache keys
- LRU eviction when cache exceeds configurable size limit (default 200 MB)
- Separate directories for media files and thumbnails
- Atomic file writes (temp file + rename) to prevent corruption
- OkHttp for reliable HTTP downloads with timeouts and retries

#### Error Handling
- Structured `WallpaperResult` returned from every operation
- `WallpaperErrorCode` enum with 11 specific error codes
- No exceptions thrown for operational failures
- Input validation at `WallpaperSource` construction time

#### Permissions
- Automatic handling across Android 7–14
- `SET_WALLPAPER` (normal, auto-granted)
- `READ_EXTERNAL_STORAGE` (API < 33) / `READ_MEDIA_*` (API 33+)
- App-internal path detection (skips permission check)
- `FEATURE_LIVE_WALLPAPER` capability check

#### Toast Customization
- Optional Android Toast notifications
- Custom success and error messages
- `showToast` flag to disable (handle UI yourself)

#### Public API
- `FlutterWallpaperPlus.setImageWallpaper()`
- `FlutterWallpaperPlus.setVideoWallpaper()`
- `FlutterWallpaperPlus.getVideoThumbnail()`
- `FlutterWallpaperPlus.clearCache()`
- `FlutterWallpaperPlus.getCacheSize()`
- `FlutterWallpaperPlus.setMaxCacheSize()`
