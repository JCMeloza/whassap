import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_transfer/src/models/device.dart';

void main() {
  group('Device', () {
    test('creates device with required fields', () {
      final device = Device(
        serial: 'abc123',
        model: 'Pixel 7',
        apiLevel: 33,
        packages: ['com.whatsapp'],
      );

      expect(device.serial, 'abc123');
      expect(device.model, 'Pixel 7');
      expect(device.apiLevel, 33);
      expect(device.packages, ['com.whatsapp']);
    });

    test('classification is "scoped" for API >= 30', () {
      final device = Device(
        serial: 's1',
        model: 'M1',
        apiLevel: 33,
        packages: [],
      );
      expect(device.classification, 'scoped');
    });

    test('classification is "legacy" for API <= 29', () {
      final device = Device(
        serial: 's2',
        model: 'M2',
        apiLevel: 29,
        packages: [],
      );
      expect(device.classification, 'legacy');
    });

    test('hasWhatsApp returns true when packages contain WhatsApp variants', () {
      final device = Device(
        serial: 's1',
        model: 'M1',
        apiLevel: 33,
        packages: ['com.whatsapp'],
      );
      expect(device.hasWhatsApp, isTrue);
    });

    test('hasWhatsApp returns true for WhatsApp Business', () {
      final device = Device(
        serial: 's2',
        model: 'M2',
        apiLevel: 30,
        packages: ['com.whatsapp.w4b'],
      );
      expect(device.hasWhatsApp, isTrue);
    });

    test('hasWhatsApp returns true for both packages', () {
      final device = Device(
        serial: 's3',
        model: 'M3',
        apiLevel: 33,
        packages: ['com.whatsapp', 'com.whatsapp.w4b'],
      );
      expect(device.hasWhatsApp, isTrue);
    });

    test('hasWhatsApp returns false when no WhatsApp packages', () {
      final device = Device(
        serial: 's4',
        model: 'M4',
        apiLevel: 31,
        packages: ['com.android.chrome'],
      );
      expect(device.hasWhatsApp, isFalse);
    });

    test('fromJson creates device from map', () {
      final device = Device.fromJson({
        'serial': 'xyz789',
        'model': 'Galaxy S23',
        'apiLevel': 33,
        'packages': ['com.whatsapp', 'com.whatsapp.w4b'],
      });

      expect(device.serial, 'xyz789');
      expect(device.model, 'Galaxy S23');
      expect(device.apiLevel, 33);
      expect(device.packages.length, 2);
      expect(device.classification, 'scoped');
    });

    test('toJson serializes correctly', () {
      final device = Device(
        serial: 's1',
        model: 'Pixel 6',
        apiLevel: 31,
        packages: ['com.whatsapp'],
      );

      final json = device.toJson();
      expect(json['serial'], 's1');
      expect(json['model'], 'Pixel 6');
      expect(json['apiLevel'], 31);
      expect(json['packages'], ['com.whatsapp']);
      expect(json['classification'], 'scoped');
    });

    test('round-trip JSON', () {
      final original = Device(
        serial: 'abc',
        model: 'OnePlus 9',
        apiLevel: 30,
        packages: ['com.whatsapp.w4b'],
      );

      final rehydrated = Device.fromJson(original.toJson());
      expect(rehydrated.serial, original.serial);
      expect(rehydrated.model, original.model);
      expect(rehydrated.apiLevel, original.apiLevel);
      expect(rehydrated.packages, original.packages);
      expect(rehydrated.classification, original.classification);
    });

    test('empty packages list', () {
      final device = Device(
        serial: 'empty',
        model: 'Test',
        apiLevel: 25,
        packages: [],
      );
      expect(device.hasWhatsApp, isFalse);
      expect(device.classification, 'legacy');
    });
  });
}
