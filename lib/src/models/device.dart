/// Model representing an Android device detected via ADB.
class Device {
  /// Device serial number (e.g., "abc123def").
  final String serial;

  /// Marketing model name (e.g., "Pixel 7", "Galaxy S23").
  final String model;

  /// Android API level (e.g., 33 for Android 13).
  final int apiLevel;

  /// List of detected WhatsApp package names.
  final List<String> packages;

  const Device({
    required this.serial,
    required this.model,
    required this.apiLevel,
    required this.packages,
  });

  /// Returns 'legacy' for API ≤ 29 (Android 10-), 'scoped' for API ≥ 30.
  String get classification => apiLevel <= 29 ? 'legacy' : 'scoped';

  /// Whether at least one WhatsApp variant is installed.
  bool get hasWhatsApp =>
      packages.contains('com.whatsapp') ||
      packages.contains('com.whatsapp.w4b');

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      serial: json['serial'] as String? ?? '',
      model: json['model'] as String? ?? '',
      apiLevel: json['apiLevel'] as int? ?? 0,
      packages: (json['packages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'serial': serial,
        'model': model,
        'apiLevel': apiLevel,
        'packages': packages,
        'classification': classification,
      };
}
