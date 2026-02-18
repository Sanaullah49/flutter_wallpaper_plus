# Changelog

## 1.0.0-dev.2

### Phase 2 — Image Wallpaper
- `ImageWallpaperManager` with WallpaperManager.setStream() for memory efficiency
- Full `handleSetImageWallpaper` implementation in method handler
- Supports all three source types: asset, file, URL
- Supports all three targets: home, lock, both
- Pre-flight checks: isWallpaperSupported, isSetWallpaperAllowed
- Storage permission check for external file sources
- App-internal path detection (skips permission check for own directories)
- Catches SecurityException, IOException, OutOfMemoryError, IllegalArgumentException
- Optional Android Toast with custom success/error messages
- Cache performance demonstrated in example app
- 70+ unit tests covering all error codes and scenarios
- Example app with URL/asset/file image wallpaper demos

## 1.0.0-dev.1

### Phase 1 — Foundation
- Dart public API with `FlutterWallpaperPlus`, `WallpaperSource`, `WallpaperTarget`, `WallpaperResult`
- Structured error handling with `WallpaperErrorCode` enum
- Input validation on all source constructors
- Kotlin plugin registration with `FlutterWallpaperPlusPlugin`
- `CacheManager` with SHA-256 hashing, LRU eviction, OkHttp downloads
- `SourceResolver` for asset/file/URL resolution
- `PermissionHelper` for cross-API-level permission checks
- `WallpaperMethodHandler` skeleton with cache operations working
- AndroidManifest with permissions and VideoWallpaperService declaration
- ProGuard rules for Media3, OkHttp, Coroutines
- 55+ unit tests passing
- Example app with cache operation demos