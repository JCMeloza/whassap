import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_transfer/src/models/scan_result.dart';

void main() {
  group('DatabaseFile', () {
    test('creates with required fields', () {
      final db = DatabaseFile(
        path: '/sdcard/WhatsApp/Databases/msgstore.db.crypt14',
        name: 'msgstore.db.crypt14',
        sizeBytes: 50000000,
        package: 'com.whatsapp',
      );

      expect(db.path, contains('msgstore.db.crypt14'));
      expect(db.name, 'msgstore.db.crypt14');
      expect(db.sizeBytes, 50000000);
      expect(db.package, 'com.whatsapp');
    });

    test('fromJson creates from map', () {
      final db = DatabaseFile.fromJson({
        'path': '/path/db.crypt14',
        'name': 'db.crypt14',
        'sizeBytes': 1000,
        'package': 'com.whatsapp.w4b',
      });

      expect(db.name, 'db.crypt14');
      expect(db.sizeBytes, 1000);
      expect(db.package, 'com.whatsapp.w4b');
    });

    test('toJson serializes correctly', () {
      final db = DatabaseFile(
        path: '/p',
        name: 'wa.db.crypt14',
        sizeBytes: 1024,
        package: 'com.whatsapp',
      );

      final json = db.toJson();
      expect(json['name'], 'wa.db.crypt14');
      expect(json['sizeBytes'], 1024);
    });
  });

  group('MediaCategory', () {
    test('creates with required fields', () {
      final media = MediaCategory(
        category: 'Images',
        path: '/sdcard/WhatsApp/Media/Images/',
        sizeBytes: 2100000000,
        package: 'com.whatsapp',
      );

      expect(media.category, 'Images');
      expect(media.sizeBytes, 2100000000);
      expect(media.package, 'com.whatsapp');
    });

    test('fromJson creates from map', () {
      final media = MediaCategory.fromJson({
        'category': 'Videos',
        'path': '/path/Videos/',
        'sizeBytes': 850000000,
        'package': 'com.whatsapp.w4b',
      });

      expect(media.category, 'Videos');
      expect(media.sizeBytes, 850000000);
    });

    test('toJson serializes correctly', () {
      final media = MediaCategory(
        category: 'Audio',
        path: '/p/Audio/',
        sizeBytes: 350000000,
        package: 'com.whatsapp',
      );

      final json = media.toJson();
      expect(json['category'], 'Audio');
      expect(json['sizeBytes'], 350000000);
    });
  });

  group('PackageData', () {
    test('calculates totalBytes from databases and media', () {
      final data = PackageData(
        package: 'com.whatsapp',
        databases: [
          DatabaseFile(path: '/p/db1', name: 'db1', sizeBytes: 100, package: 'com.whatsapp'),
          DatabaseFile(path: '/p/db2', name: 'db2', sizeBytes: 200, package: 'com.whatsapp'),
        ],
        media: [
          MediaCategory(category: 'Images', path: '/p/Images/', sizeBytes: 500, package: 'com.whatsapp'),
        ],
      );

      expect(data.totalBytes, 800);
    });

    test('totalBytes is 0 with empty lists', () {
      final data = PackageData(
        package: 'com.whatsapp',
        databases: [],
        media: [],
      );

      expect(data.totalBytes, 0);
    });

    test('fromJson creates from map', () {
      final data = PackageData.fromJson({
        'package': 'com.whatsapp.w4b',
        'databases': [
          {'path': '/p/db', 'name': 'db.crypt14', 'sizeBytes': 500, 'package': 'com.whatsapp.w4b'},
        ],
        'media': [
          {'category': 'Documents', 'path': '/p/Docs/', 'sizeBytes': 200, 'package': 'com.whatsapp.w4b'},
        ],
      });

      expect(data.package, 'com.whatsapp.w4b');
      expect(data.databases.length, 1);
      expect(data.media.length, 1);
      expect(data.totalBytes, 700);
    });
  });

  group('ScanResult', () {
    test('aggregates multiple packages', () {
      final result = ScanResult(packages: [
        PackageData(
          package: 'com.whatsapp',
          databases: [DatabaseFile(path: '/p/d1', name: 'd1', sizeBytes: 100, package: 'com.whatsapp')],
          media: [],
        ),
        PackageData(
          package: 'com.whatsapp.w4b',
          databases: [],
          media: [MediaCategory(category: 'Audio', path: '/p/Audio/', sizeBytes: 300, package: 'com.whatsapp.w4b')],
        ),
      ]);

      expect(result.totalBytes, 400);
      expect(result.allDatabases.length, 1);
      expect(result.allMedia.length, 1);
    });

    test('fromJson creates ScanResult', () {
      final json = {
        'scanResults': [
          {
            'package': 'com.whatsapp',
            'databases': [],
            'media': [],
            'totalBytes': 0,
          },
        ],
      };

      final result = ScanResult.fromJson(json);
      expect(result.packages.length, 1);
      expect(result.packages[0].package, 'com.whatsapp');
      expect(result.totalBytes, 0);
    });
  });
}
