# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] — 2026-03-18

### Changed
- README host lifecycle guidance now documents the full cached-engine pattern for wallpaper flows, including explicit cached-engine teardown when the host activity is genuinely finishing.
- Example Android app `MainActivity` now destroys its cached `FlutterEngine` on real app exit so users do not return to a stale Dart isolate after intentionally closing the app.
- Package documentation now reflects that Wallpaper Auto Change is already available in the published package, rather than only on the `main` branch.

## [1.1.0] — 2026-03-17

### Added
- Android Wallpaper Auto Change V1 for static images, including `startWallpaperAutoChange(...)`, `stopWallpaperAutoChange()`, `getWallpaperAutoChangeStatus()`, and `applyNextWallpaperNow()`.
- Up-front source preparation into app-internal storage so scheduled changes continue to work without Flutter asset access or live network fetches in the background worker.
- WorkManager-based one-shot rescheduling for Auto Change so intervals can start at 1 minute while still continuing after the app is closed.
- Example app Auto Change panel for quick real-device verification of `home`, `lock`, and `both` target behavior.

## [1.0.4] — 2026-03-16

### Fixed
- Android image wallpaper `lock` and `both` targets now retry with a bitmap-based compatibility fallback after the normalized stream apply path, improving reliability on OEM ROMs where lock-screen wallpaper updates behave more like `async_wallpaper 2.1.0` than `WallpaperManager.setStream()`.

## [1.0.3] — 2026-03-12

### Fixed
- Android image wallpaper apply now downscales and normalizes oversized image sources before calling `WallpaperManager`, reducing memory pressure and improving stability on devices where the system wallpaper service could die during large image applies.

### Added
- README guidance for host apps that see `FlutterActivity` recreation / `FlutterEngine` detach-reattach after wallpaper apply, including a copy-paste `MainActivity` example using `RenderMode.texture` and a cached engine.

## [1.0.2] — 2026-02-24

### Fixed
- Image wallpaper `both` target now uses sequential writes with 500ms delay, matching the working approach from `async_wallpaper`. This fixes failure on restrictive OEMs (Xiaomi/Redmi/Oppo/Vivo/Realme) where the previous combined-flags approach was unreliable.
- Removed OEM restriction blocking - the plugin now allows lock/both targets on all OEMs and relies on sequential writes for reliability.

### Changed
- Updated example app to enable all target buttons regardless of OEM (previously disabled on restrictive OEMs).

## [1.0.1] — 2026-02-20

### Fixed
- Android live wallpaper setup now persists the selected video into dedicated app-internal storage before launching the system chooser, so active live wallpapers are not broken by cache eviction/cleanup.
- Applied the same persistence path for both `setVideoWallpaper(...)` and `openNativeWallpaperChooser(...)` video flows to keep behavior consistent.

## [1.0.0] — 2026-02-18

### Changed
- Android live wallpaper service label now inherits the host app label, so the picker shows the app name instead of a hardcoded "Video Wallpaper" label.

### Fixed
- Android example app no longer goes black/white after wallpaper apply on OEMs that recreate the activity (e.g., MIUI): `MainActivity` now reuses a cached `FlutterEngine` across host activity recreation.
- Android live wallpaper target handling now validates unsupported `lock`-only requests and improves `home` behavior by creating a dedicated lock wallpaper snapshot before launching the system picker (best effort, OEM-dependent).
- Android image wallpaper `both` target now applies OEM fallback (combined flags, then explicit home+lock writes on known restrictive OEMs) and reports `manufacturerRestriction` when lock updates are blocked.
- Android live wallpaper home-target lock snapshot now uses permission-independent bitmap fallback when direct wallpaper file read is restricted by OEM permission policy.
- Android now fail-fast returns `manufacturerRestriction` for lock/both targets on known restrictive OEMs (Xiaomi/Redmi/Oppo/Vivo/Realme) to avoid misleading success.

### Added

#### Chooser & UX
- Added `FlutterWallpaperPlus.openNativeWallpaperChooser(source: ...)` with required `WallpaperSource` (asset/file/url) to open native chooser flow from explicit media source.
- Added optional `goToHome` flag across public plugin methods for best-effort app minimization/home navigation behavior.

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
- `FlutterWallpaperPlus.getTargetSupportPolicy()`
- `FlutterWallpaperPlus.clearCache()`
- `FlutterWallpaperPlus.getCacheSize()`
- `FlutterWallpaperPlus.setMaxCacheSize()`
