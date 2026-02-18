# Changelog

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