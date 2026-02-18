import 'wallpaper_error_code.dart';

/// Structured result from any wallpaper operation.
///
/// Every plugin method returns a [WallpaperResult] instead of throwing
/// exceptions, allowing callers to handle errors declaratively.
///
/// ```dart
/// final result = await FlutterWallpaperPlus.setImageWallpaper(
///   source: WallpaperSource.url('https://example.com/bg.jpg'),
///   target: WallpaperTarget.home,
/// );
///
/// if (result.success) {
///   print(result.message); // "Wallpaper set successfully"
/// } else {
///   print(result.errorCode); // WallpaperErrorCode.downloadFailed
///   print(result.message);   // "Download failed: HTTP 404"
/// }
/// ```
class WallpaperResult {
  const WallpaperResult({
    required this.success,
    required this.message,
    this.errorCode = WallpaperErrorCode.none,
  });

  /// Creates a [WallpaperResult] from a platform channel response map.
  ///
  /// Expected map structure:
  /// ```
  /// {
  ///   "success": bool,
  ///   "message": String,
  ///   "errorCode": String  // matches WallpaperErrorCode.name
  /// }
  /// ```
  factory WallpaperResult.fromMap(Map<dynamic, dynamic> map) {
    return WallpaperResult(
      success: map['success'] as bool? ?? false,
      message: map['message'] as String? ?? 'Unknown result',
      errorCode: WallpaperErrorCodeParsing.fromString(
        map['errorCode'] as String?,
      ),
    );
  }

  /// Whether the operation completed successfully.
  final bool success;

  /// Human-readable description of the outcome.
  ///
  /// For successful operations, this contains the success message
  /// (customizable via the [successMessage] parameter).
  ///
  /// For failures, this contains a descriptive error message.
  final String message;

  /// Machine-readable error code for programmatic handling.
  ///
  /// Always [WallpaperErrorCode.none] when [success] is true.
  final WallpaperErrorCode errorCode;

  /// Convenience getter: returns true if the operation failed.
  bool get isError => !success;

  @override
  String toString() =>
      'WallpaperResult('
      'success: $success, '
      'message: $message, '
      'errorCode: ${errorCode.name}'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WallpaperResult &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          message == other.message &&
          errorCode == other.errorCode;

  @override
  int get hashCode => Object.hash(success, message, errorCode);
}
