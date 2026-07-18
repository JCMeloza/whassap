/// A WhatsApp database file discovered on a device.
class DatabaseFile {
  final String path;
  final String name;
  final int sizeBytes;
  final String package;

  const DatabaseFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.package,
  });

  factory DatabaseFile.fromJson(Map<String, dynamic> json) {
    return DatabaseFile(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      package: json['package'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'sizeBytes': sizeBytes,
        'package': package,
      };
}

/// A WhatsApp media category discovered on a device.
class MediaCategory {
  final String category;
  final String path;
  final int sizeBytes;
  final String package;

  const MediaCategory({
    required this.category,
    required this.path,
    required this.sizeBytes,
    required this.package,
  });

  factory MediaCategory.fromJson(Map<String, dynamic> json) {
    return MediaCategory(
      category: json['category'] as String? ?? '',
      path: json['path'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      package: json['package'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'path': path,
        'sizeBytes': sizeBytes,
        'package': package,
      };
}

/// Data for a single WhatsApp package discovered on a device.
class PackageData {
  final String package;
  final List<DatabaseFile> databases;
  final List<MediaCategory> media;

  const PackageData({
    required this.package,
    required this.databases,
    required this.media,
  });

  int get totalBytes =>
      databases.fold(0, (sum, db) => sum + db.sizeBytes) +
      media.fold(0, (sum, m) => sum + m.sizeBytes);

  factory PackageData.fromJson(Map<String, dynamic> json) {
    return PackageData(
      package: json['package'] as String? ?? '',
      databases: (json['databases'] as List<dynamic>?)
              ?.map((e) => DatabaseFile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      media: (json['media'] as List<dynamic>?)
              ?.map((e) => MediaCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'package': package,
        'databases': databases.map((d) => d.toJson()).toList(),
        'media': media.map((m) => m.toJson()).toList(),
        'totalBytes': totalBytes,
      };
}

/// Aggregated scan result from backend response.
class ScanResult {
  final List<PackageData> packages;

  const ScanResult({required this.packages});

  int get totalBytes =>
      packages.fold(0, (sum, p) => sum + p.totalBytes);

  List<DatabaseFile> get allDatabases =>
      packages.expand((p) => p.databases).toList();

  List<MediaCategory> get allMedia =>
      packages.expand((p) => p.media).toList();

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final results = json['scanResults'] as List<dynamic>? ?? [];
    return ScanResult(
      packages: results
          .map((e) => PackageData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
