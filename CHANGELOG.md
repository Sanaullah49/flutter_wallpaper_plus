# Changelog

## 1.0.0-dev.3

### Phase 3 — Video (Live) Wallpaper
- `VideoRenderer` — ExoPlayer lifecycle wrapper with play/pause/release
- `VideoWallpaperService` — Android WallpaperService with inner Engine
- Survives app kill via SharedPreferences config persistence
- Handles screen rotation via onSurfaceChanged
- Pauses when not visible, resumes when home screen shown (battery saving)
- Audio enable/disable at runtime via volume control
- Seamless looping via Player.REPEAT_MODE_ALL
- Player error recovery (seek to start + re-prepare)
- Touch events pass through to launcher
- Two-strategy intent launching (direct component → fallback picker)
- Source resolution: asset/file/URL with caching
- Full error handling: unsupported device, download failure, source not found
- 80+ unit tests covering all video wallpaper scenarios
- Example app with 4 video wallpaper demo buttons

## 1.0.0-dev.2

### Phase 2 — Image Wallpaper
- `ImageWallpaperManager` with WallpaperManager.setStream()
- Memory-efficient streaming (no full bitmap in memory)
- Pre-flight checks: isWallpaperSupported, isSetWallpaperAllowed
- FLAG_SYSTEM / FLAG_LOCK / both support
- Storage permission check for external files
- App-internal path detection
- Catches SecurityException, IOException, OutOfMemoryError
- Optional Toast with custom messages
- 70+ unit tests

## 1.0.0-dev.1

### Phase 1 — Foundation
- Dart public API with structured error handling
- CacheManager with SHA-256 hashing, LRU eviction, OkHttp downloads
- SourceResolver for asset/file/URL resolution
- PermissionHelper for cross-API-level permission checks
- 55+ unit tests