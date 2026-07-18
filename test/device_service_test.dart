import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_transfer/src/services/device_service.dart';
import 'package:whatsapp_transfer/src/services/backend_client.dart';

/// A mock transport that auto-responds based on the request method.
class MockAutoTransport extends BackendTransport {
  final _outgoing = StreamController<List<int>>();

  @override
  Stream<List<int>> get stdout => _outgoing.stream;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  void addStdin(List<int> data) {
    final sent = utf8.decode(data).trim();
    final reqJson = jsonDecode(sent) as Map<String, dynamic>;
    final reqId = reqJson['id'] as String;
    final method = reqJson['method'] as String;

    final response = _makeResponse(reqId, method);
    _outgoing.add(utf8.encode('${jsonEncode(response)}\n'));
  }

  Map<String, dynamic> _makeResponse(String id, String method) {
    switch (method) {
      case 'device.list':
        return {
          'type': 'response', 'id': id, 'result': {
            'devices': [
              {'serial': 'abc123', 'model': 'Pixel 7', 'apiLevel': 33, 'packages': ['com.whatsapp'], 'classification': 'scoped'},
              {'serial': 'def456', 'model': 'Galaxy S23', 'apiLevel': 29, 'packages': ['com.whatsapp.w4b'], 'classification': 'legacy'},
            ],
          },
        };
      case 'device.properties':
        return {
          'type': 'response', 'id': id, 'result': {
            'ro.product.model': 'Pixel 7',
            'ro.build.version.sdk': '33',
          },
        };
      case 'device.packages':
        return {
          'type': 'response', 'id': id, 'result': {
            'packages': ['com.whatsapp', 'com.whatsapp.w4b'],
          },
        };
      default:
        return {'type': 'response', 'id': id, 'result': {}};
    }
  }

  @override
  Future<void> close() async { await _outgoing.close(); }
  @override
  Future<int> get exitCode => Future.value(0);
}

/// Mock transport that returns an empty device list.
class MockEmptyTransport extends BackendTransport {
  final _outgoing = StreamController<List<int>>();

  @override
  Stream<List<int>> get stdout => _outgoing.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  void addStdin(List<int> data) {
    final sent = utf8.decode(data).trim();
    final reqJson = jsonDecode(sent) as Map<String, dynamic>;
    final reqId = reqJson['id'] as String;
    _outgoing.add(utf8.encode('{"type":"response","id":"$reqId","result":{"devices":[]}}\n'));
  }

  @override
  Future<void> close() async { await _outgoing.close(); }
  @override
  Future<int> get exitCode => Future.value(0);
}

/// Mock transport with a mix of WhatsApp and non-WhatsApp devices.
class MockFilterTransport extends BackendTransport {
  final _outgoing = StreamController<List<int>>();

  @override
  Stream<List<int>> get stdout => _outgoing.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  void addStdin(List<int> data) {
    final sent = utf8.decode(data).trim();
    final reqJson = jsonDecode(sent) as Map<String, dynamic>;
    final reqId = reqJson['id'] as String;
    _outgoing.add(utf8.encode(
      '{"type":"response","id":"$reqId","result":{"devices":['
      '{"serial":"wa-only","model":"M1","apiLevel":33,"packages":["com.whatsapp"],"classification":"scoped"},'
      '{"serial":"no-wa","model":"M2","apiLevel":31,"packages":["com.android.chrome"],"classification":"scoped"}'
      ']}}\n',
    ));
  }

  @override
  Future<void> close() async { await _outgoing.close(); }
  @override
  Future<int> get exitCode => Future.value(0);
}

void main() {
  group('DeviceService', () {
    test('listDevices returns parsed devices', () async {
      final transport = MockAutoTransport();
      final client = BackendClient(transport: transport);
      final service = DeviceService(client);

      final devices = await service.listDevices();

      expect(devices.length, 2);
      expect(devices[0].serial, 'abc123');
      expect(devices[0].model, 'Pixel 7');
      expect(devices[0].apiLevel, 33);
      expect(devices[0].packages, ['com.whatsapp']);
      expect(devices[0].classification, 'scoped');
      expect(devices[1].serial, 'def456');
      expect(devices[1].classification, 'legacy');

      await client.dispose();
    });

    test('listDevices returns empty list when no devices', () async {
      final transport = MockEmptyTransport();
      final client = BackendClient(transport: transport);
      final service = DeviceService(client);

      final devices = await service.listDevices();
      expect(devices, isEmpty);
      await client.dispose();
    });

    test('getProperties returns property map', () async {
      final transport = MockAutoTransport();
      final client = BackendClient(transport: transport);
      final service = DeviceService(client);

      final props = await service.getProperties('abc123');
      expect(props['ro.product.model'], 'Pixel 7');
      expect(props['ro.build.version.sdk'], '33');
      await client.dispose();
    });

    test('detectPackages returns package list', () async {
      final transport = MockAutoTransport();
      final client = BackendClient(transport: transport);
      final service = DeviceService(client);

      final packages = await service.detectPackages('abc123');
      expect(packages, contains('com.whatsapp'));
      expect(packages, contains('com.whatsapp.w4b'));
      await client.dispose();
    });

    test('listDevicesWithWhatsApp filters devices without WhatsApp', () async {
      final transport = MockFilterTransport();
      final client = BackendClient(transport: transport);
      final service = DeviceService(client);

      final waDevices = await service.listDevicesWithWhatsApp();
      expect(waDevices.length, 1);
      expect(waDevices[0].serial, 'wa-only');
      await client.dispose();
    });
  });
}
