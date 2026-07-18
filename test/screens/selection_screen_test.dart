import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_transfer/src/models/device.dart';
import 'package:whatsapp_transfer/src/models/scan_result.dart';
import 'package:whatsapp_transfer/src/providers/device_provider.dart';
import 'package:whatsapp_transfer/src/providers/scan_provider.dart';
import 'package:whatsapp_transfer/src/screens/selection_screen.dart';
import 'package:whatsapp_transfer/src/services/backend_client.dart';
import 'package:whatsapp_transfer/src/services/device_service.dart';

/// A mock transport that responds to calls.
class _MockDevicesTransport extends BackendTransport {
  final _ctrl = StreamController<List<int>>();

  @override
  Stream<List<int>> get stdout => _ctrl.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  void addStdin(List<int> data) {
    final line = utf8.decode(data).trim();
    final req = jsonDecode(line) as Map<String, dynamic>;
    final id = req['id'] as String;
    _ctrl.add(utf8.encode(
      '{"type":"response","id":"$id","result":{"devices":[]}}\n',
    ));
  }

  @override
  Future<void> close() async => _ctrl.close();
  @override
  Future<int> get exitCode => Future.value(0);
}

Widget _wrapSelectionScreen({
  required ScanProvider scanProvider,
  required DeviceProvider deviceProvider,
}) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<DeviceProvider>.value(value: deviceProvider),
        ChangeNotifierProvider<ScanProvider>.value(value: scanProvider),
      ],
      child: const SelectionScreen(),
    ),
  );
}

void main() {
  group('SelectionScreen', () {
    late ScanResult scanResult;
    late Device sourceDevice;
    late Device destDevice;

    setUp(() {
      scanResult = ScanResult(packages: [
        PackageData(
          package: 'com.whatsapp',
          databases: [
            DatabaseFile(
              path: 'Databases/msgstore.db.crypt14',
              name: 'msgstore.db.crypt14',
              sizeBytes: 50000000,
              package: 'com.whatsapp',
            ),
            DatabaseFile(
              path: 'Databases/wa.db.crypt14',
              name: 'wa.db.crypt14',
              sizeBytes: 1000000,
              package: 'com.whatsapp',
            ),
          ],
          media: [
            MediaCategory(
              category: 'Images',
              path: 'Media/Images',
              sizeBytes: 2100000000,
              package: 'com.whatsapp',
            ),
            MediaCategory(
              category: 'Video',
              path: 'Media/Video',
              sizeBytes: 850000000,
              package: 'com.whatsapp',
            ),
          ],
        ),
      ]);
      sourceDevice = Device(
        serial: 'src123',
        model: 'Pixel 7',
        apiLevel: 33,
        packages: ['com.whatsapp'],
      );
      destDevice = Device(
        serial: 'dst456',
        model: 'Galaxy S23',
        apiLevel: 29,
        packages: ['com.whatsapp.w4b'],
      );
    });

    testWidgets('shows scan results with package info', (tester) async {
      final scanClient = BackendClient(transport: _MockDevicesTransport());
      final scanProvider = ScanProvider(scanClient);
      scanProvider.updateScanResult(scanResult);
      final deviceClient = BackendClient(transport: _MockDevicesTransport());
      final deviceProvider = DeviceProvider(DeviceService(deviceClient));
      deviceProvider.setSourceDevice(sourceDevice);
      deviceProvider.setDestDevice(destDevice);

      addTearDown(() {
        deviceProvider.dispose();
        scanClient.dispose();
        deviceClient.dispose();
      });

      await tester.pumpWidget(_wrapSelectionScreen(
        scanProvider: scanProvider,
        deviceProvider: deviceProvider,
      ));
      await tester.pump();

      expect(find.textContaining('WhatsApp'), findsWidgets);
    });

    testWidgets('shows scan results with database and media info',
        (tester) async {
      final scanClient = BackendClient(transport: _MockDevicesTransport());
      final scanProvider = ScanProvider(scanClient);
      scanProvider.updateScanResult(scanResult);
      final deviceClient = BackendClient(transport: _MockDevicesTransport());
      final deviceProvider = DeviceProvider(DeviceService(deviceClient));
      deviceProvider.setSourceDevice(sourceDevice);
      deviceProvider.setDestDevice(destDevice);

      addTearDown(() {
        deviceProvider.dispose();
        scanClient.dispose();
        deviceClient.dispose();
      });

      await tester.pumpWidget(_wrapSelectionScreen(
        scanProvider: scanProvider,
        deviceProvider: deviceProvider,
      ));
      await tester.pump();

      expect(find.textContaining('Bases de datos'), findsWidgets);
      expect(find.textContaining('Multimedia'), findsWidgets);
    });

    testWidgets('shows Start Transfer button', (tester) async {
      final scanClient = BackendClient(transport: _MockDevicesTransport());
      final scanProvider = ScanProvider(scanClient);
      scanProvider.updateScanResult(scanResult);
      final deviceClient = BackendClient(transport: _MockDevicesTransport());
      final deviceProvider = DeviceProvider(DeviceService(deviceClient));
      deviceProvider.setSourceDevice(sourceDevice);
      deviceProvider.setDestDevice(destDevice);

      addTearDown(() {
        deviceProvider.dispose();
        scanClient.dispose();
        deviceClient.dispose();
      });

      await tester.pumpWidget(_wrapSelectionScreen(
        scanProvider: scanProvider,
        deviceProvider: deviceProvider,
      ));
      await tester.pump();

      expect(find.text('Iniciar transferencia'), findsOneWidget);
    });

    testWidgets('toggling databases updates size', (tester) async {
      final scanClient = BackendClient(transport: _MockDevicesTransport());
      final scanProvider = ScanProvider(scanClient);
      scanProvider.updateScanResult(scanResult);
      final deviceClient = BackendClient(transport: _MockDevicesTransport());
      final deviceProvider = DeviceProvider(DeviceService(deviceClient));
      deviceProvider.setSourceDevice(sourceDevice);
      deviceProvider.setDestDevice(destDevice);

      addTearDown(() {
        deviceProvider.dispose();
        scanClient.dispose();
        deviceClient.dispose();
      });

      await tester.pumpWidget(_wrapSelectionScreen(
        scanProvider: scanProvider,
        deviceProvider: deviceProvider,
      ));
      await tester.pump();

      // Toggle databases off
      scanProvider.toggleDatabases();
      await tester.pump();

      // Should still show Start Transfer (media is still selected)
      expect(find.text('Iniciar transferencia'), findsOneWidget);
    });

    testWidgets('shows source and dest device info', (tester) async {
      final scanClient = BackendClient(transport: _MockDevicesTransport());
      final scanProvider = ScanProvider(scanClient);
      scanProvider.updateScanResult(scanResult);
      final deviceClient = BackendClient(transport: _MockDevicesTransport());
      final deviceProvider = DeviceProvider(DeviceService(deviceClient));
      deviceProvider.setSourceDevice(sourceDevice);
      deviceProvider.setDestDevice(destDevice);

      addTearDown(() {
        deviceProvider.dispose();
        scanClient.dispose();
        deviceClient.dispose();
      });

      await tester.pumpWidget(_wrapSelectionScreen(
        scanProvider: scanProvider,
        deviceProvider: deviceProvider,
      ));
      await tester.pump();

      expect(find.textContaining('Pixel 7'), findsOneWidget);
      expect(find.textContaining('Galaxy S23'), findsOneWidget);
    });
  });
}
