# Changelog

## 1.0.0-dev.4

### Phase 4 — Thumbnail Generation
- `ThumbnailGenerator` using MediaMetadataRetriever
- Frame extraction at 1 second with 3-level fallback strategy
- Proportional scaling to max 480px dimension
- JPEG compression with configurable quality (1-100)
- Thumbnail caching via CacheManager (read and write)
- Full `handleGetVideoThumbnail` in WallpaperMethodHandler
- Supports all source types: asset, file, URL
- Handles corrupt files, unsupported codecs, OOM gracefully
- Explicit Bitmap recycling for memory efficiency
- 90+ unit tests covering quality clamping, cache flag, error cases
- Example app with thumbnail preview, quality comparison, cache test

## 1.0.0-dev.3

### Phase 3 — Video (Live) Wallpaper
- `VideoRenderer` — ExoPlayer lifecycle wrapper
- `VideoWallpaperService` — WallpaperService with inner Engine
- Survives app kill, handles rotation, visibility-based pause/resume
- Audio toggle, seamless loop, error recovery
- Two-strategy intent launch (direct + fallback)
- 80+ unit tests

## 1.0.0-dev.2

### Phase 2 — Image Wallpaper
- `ImageWallpaperManager` with WallpaperManager.setStream()
- FLAG_SYSTEM / FLAG_LOCK / both, pre-flight checks
- 70+ unit tests

## 1.0.0-dev.1

### Phase 1 — Foundation
- Dart API, CacheManager, SourceResolver, PermissionHelper
- 55+ unit tests