/// Device-specific target support policy reported by the Android layer.
///
/// This helps apps disable unsupported or unreliable target combinations
/// before showing wallpaper actions to users.
class TargetSupportPolicy {
  const TargetSupportPolicy({
    required this.manufacturer,
    required this.model,
    required this.restrictiveOem,
    required this.allowImageHome,
    required this.allowImageLock,
    required this.allowImageBoth,
    required this.allowVideoHome,
    required this.allowVideoLock,
    required this.allowVideoBoth,
  });

  factory TargetSupportPolicy.fromMap(Map<dynamic, dynamic>? map) {
    final data = map ?? const <dynamic, dynamic>{};
    return TargetSupportPolicy(
      manufacturer: (data['manufacturer'] as String?) ?? 'unknown',
      model: (data['model'] as String?) ?? 'unknown',
      restrictiveOem: (data['restrictiveOem'] as bool?) ?? false,
      allowImageHome: (data['allowImageHome'] as bool?) ?? true,
      allowImageLock: (data['allowImageLock'] as bool?) ?? true,
      allowImageBoth: (data['allowImageBoth'] as bool?) ?? true,
      allowVideoHome: (data['allowVideoHome'] as bool?) ?? true,
      allowVideoLock: (data['allowVideoLock'] as bool?) ?? false,
      allowVideoBoth: (data['allowVideoBoth'] as bool?) ?? true,
    );
  }

  static const TargetSupportPolicy unknown = TargetSupportPolicy(
    manufacturer: 'unknown',
    model: 'unknown',
    restrictiveOem: false,
    allowImageHome: true,
    allowImageLock: true,
    allowImageBoth: true,
    allowVideoHome: true,
    allowVideoLock: false,
    allowVideoBoth: true,
  );

  final String manufacturer;
  final String model;
  final bool restrictiveOem;
  final bool allowImageHome;
  final bool allowImageLock;
  final bool allowImageBoth;
  final bool allowVideoHome;
  final bool allowVideoLock;
  final bool allowVideoBoth;

  @override
  String toString() {
    return 'TargetSupportPolicy('
        'manufacturer: $manufacturer, '
        'model: $model, '
        'restrictiveOem: $restrictiveOem, '
        'allowImageHome: $allowImageHome, '
        'allowImageLock: $allowImageLock, '
        'allowImageBoth: $allowImageBoth, '
        'allowVideoHome: $allowVideoHome, '
        'allowVideoLock: $allowVideoLock, '
        'allowVideoBoth: $allowVideoBoth'
        ')';
  }
}
