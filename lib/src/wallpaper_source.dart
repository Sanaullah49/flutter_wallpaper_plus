/// Defines how wallpaper content is sourced.
///
/// Use the named constructors to create instances:
/// ```dart
/// WallpaperSource.asset('assets/bg.jpg')
/// WallpaperSource.file('/storage/emulated/0/bg.jpg')
/// WallpaperSource.url('https://example.com/bg.jpg')
/// ```
enum WallpaperSourceType {
  /// Flutter asset bundled with the app.
  asset,

  /// Absolute file path on the device filesystem.
  file,

  /// Remote URL — the plugin will download and cache it.
  url,
}

/// Immutable descriptor for where wallpaper content comes from.
///
/// Validates inputs at construction time so invalid sources
/// never reach the platform layer.
class WallpaperSource {
  const WallpaperSource._({required this.type, required this.path});

  /// Creates a source from a Flutter asset path.
  ///
  /// The [assetPath] must match an entry in your pubspec.yaml assets.
  ///
  /// ```dart
  /// final source = WallpaperSource.asset('assets/wallpapers/nature.jpg');
  /// ```
  ///
  /// Throws [ArgumentError] if [assetPath] is empty.
  factory WallpaperSource.asset(String assetPath) {
    if (assetPath.trim().isEmpty) {
      throw ArgumentError.value(
        assetPath,
        'assetPath',
        'Asset path must not be empty',
      );
    }
    return WallpaperSource._(
      type: WallpaperSourceType.asset,
      path: assetPath.trim(),
    );
  }

  /// Creates a source from an absolute file system path.
  ///
  /// The file must exist and be readable at the time [setImageWallpaper]
  /// or [setVideoWallpaper] is called.
  ///
  /// ```dart
  /// final source = WallpaperSource.file('/storage/emulated/0/DCIM/bg.jpg');
  /// ```
  ///
  /// Throws [ArgumentError] if [filePath] is empty.
  factory WallpaperSource.file(String filePath) {
    if (filePath.trim().isEmpty) {
      throw ArgumentError.value(
        filePath,
        'filePath',
        'File path must not be empty',
      );
    }
    return WallpaperSource._(
      type: WallpaperSourceType.file,
      path: filePath.trim(),
    );
  }

  /// Creates a source from a remote URL.
  ///
  /// The plugin downloads the file, caches it locally, then applies it.
  /// Subsequent calls with the same URL use the cached version.
  ///
  /// ```dart
  /// final source = WallpaperSource.url('https://example.com/wallpaper.mp4');
  /// ```
  ///
  /// Throws [ArgumentError] if [url] is empty or not a valid URL.
  factory WallpaperSource.url(String url) {
    if (url.trim().isEmpty) {
      throw ArgumentError.value(url, 'url', 'URL must not be empty');
    }

    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);

    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ArgumentError.value(
        url,
        'url',
        'Must be a valid URL with scheme and authority',
      );
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError.value(
        url,
        'url',
        'Only http and https URLs are supported',
      );
    }

    return WallpaperSource._(type: WallpaperSourceType.url, path: trimmed);
  }

  /// The type of source (asset, file, or url).
  final WallpaperSourceType type;

  /// The path, file path, or URL string.
  final String path;

  /// Serializes this source to a map for the platform channel.
  Map<String, String> toMap() => {'type': type.name, 'path': path};

  @override
  String toString() => 'WallpaperSource(type: ${type.name}, path: $path)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WallpaperSource &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          path == other.path;

  @override
  int get hashCode => Object.hash(type, path);
}
