import 'wallpaper_target.dart';

/// Current status of the wallpaper auto change engine.
class WallpaperAutoChangeStatus {
  /// Creates a status snapshot.
  const WallpaperAutoChangeStatus({
    required this.isRunning,
    required this.intervalMinutes,
    required this.nextIndex,
    required this.totalCount,
    required this.nextRunEpochMs,
    required this.target,
    this.lastError,
  });

  /// Creates a stopped/default status.
  const WallpaperAutoChangeStatus.stopped()
    : isRunning = false,
      intervalMinutes = 0,
      nextIndex = 0,
      totalCount = 0,
      nextRunEpochMs = 0,
      target = WallpaperTarget.home,
      lastError = null;

  /// Parses a platform-channel response map into a strongly typed status.
  factory WallpaperAutoChangeStatus.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const WallpaperAutoChangeStatus.stopped();
    }

    final targetName = map['target'] as String?;
    final target = WallpaperTarget.values.firstWhere(
      (value) => value.name == targetName,
      orElse: () => WallpaperTarget.home,
    );

    return WallpaperAutoChangeStatus(
      isRunning: map['isRunning'] as bool? ?? false,
      intervalMinutes: (map['intervalMinutes'] as num?)?.toInt() ?? 0,
      nextIndex: (map['nextIndex'] as num?)?.toInt() ?? 0,
      totalCount: (map['totalCount'] as num?)?.toInt() ?? 0,
      nextRunEpochMs: (map['nextRunEpochMs'] as num?)?.toInt() ?? 0,
      target: target,
      lastError: map['lastError'] as String?,
    );
  }

  /// Whether Auto Change is currently active.
  final bool isRunning;

  /// Interval between wallpaper changes in minutes.
  final int intervalMinutes;

  /// Zero-based index of the next wallpaper that will be applied.
  final int nextIndex;

  /// Total number of wallpapers in the current playlist.
  final int totalCount;

  /// Next scheduled run time in Unix epoch milliseconds.
  ///
  /// `0` means there is no scheduled run.
  final int nextRunEpochMs;

  /// Target screen(s) the Auto Change engine applies to.
  final WallpaperTarget target;

  /// Last recorded platform error, if any.
  final String? lastError;

  /// Convenience getter for the next scheduled run time.
  DateTime? get nextRunAt => nextRunEpochMs > 0
      ? DateTime.fromMillisecondsSinceEpoch(nextRunEpochMs)
      : null;

  @override
  String toString() =>
      'WallpaperAutoChangeStatus('
      'isRunning: $isRunning, '
      'intervalMinutes: $intervalMinutes, '
      'nextIndex: $nextIndex, '
      'totalCount: $totalCount, '
      'nextRunEpochMs: $nextRunEpochMs, '
      'target: ${target.name}, '
      'lastError: $lastError'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WallpaperAutoChangeStatus &&
          runtimeType == other.runtimeType &&
          isRunning == other.isRunning &&
          intervalMinutes == other.intervalMinutes &&
          nextIndex == other.nextIndex &&
          totalCount == other.totalCount &&
          nextRunEpochMs == other.nextRunEpochMs &&
          target == other.target &&
          lastError == other.lastError;

  @override
  int get hashCode => Object.hash(
    isRunning,
    intervalMinutes,
    nextIndex,
    totalCount,
    nextRunEpochMs,
    target,
    lastError,
  );
}
