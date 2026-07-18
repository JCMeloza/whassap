import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_transfer/src/models/device.dart';
import 'package:whatsapp_transfer/src/providers/device_provider.dart';
import 'package:whatsapp_transfer/src/screens/home_screen.dart';
import 'package:whatsapp_transfer/src/services/backend_client.dart';
import 'package:whatsapp_transfer/src/services/device_service.dart';

/// A mock transport that responds to device.list with a controlled device list.
class _DeviceListTransport extends BackendTransport {
  final _ctrl = StreamController<List<int>>();
  final List<Device> devices;

  _DeviceListTransport({this.devices = const []});

  @override
  Stream<List<int>> get stdout => _ctrl.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  void addStdin(List<int> data) {
    final line = utf8.decode(data).trim();
    final req = jsonDecode(line) as Map<String, dynamic>;
    final id = req['id'] as String;
    final resp = jsonEncode({
      'type': 'response',
      'id': id,
      'result': {
        'devices': devices.map((d) => d.toJson()).toList(),
      },
    });
    _ctrl.add(utf8.encode('$resp\n'));
  }

  @override
  Future<void> close() async => _ctrl.close();
  @override
  Future<int> get exitCode => Future.value(0);
}

Widget _wrapHomeScreen(DeviceProvider provider) {
  return MaterialApp(
    home: ChangeNotifierProvider<DeviceProvider>.value(
      value: provider,
      child: const HomeScreen(),
    ),
  );
}

/// Helper: creates a provider, sets up cleanup, pumps.
Future<void> _pumpWithDevices(
  WidgetTester tester,
  List<Device> devices,
) async {
  final transport = _DeviceListTransport(devices: devices);
  final client = BackendClient(transport: transport);
  final provider = DeviceProvider(DeviceService(client));
  await tester.pumpWidget(_wrapHomeScreen(provider));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  provider.stopPolling(); // Kill timer before assertions
  return;
}

void main() {
  group('HomeScreen', () {
    late Device device1;
    late Device device2;

    setUp(() {
      device1 = Device(
        serial: 'abc123',
        model: 'Pixel 7',
        apiLevel: 33,
        packages: ['com.whatsapp'],
      );
      device2 = Device(
        serial: 'def456',
        model: 'Galaxy S23',
        apiLevel: 29,
        packages: ['com.whatsapp.w4b'],
      );
    });

    testWidgets('shows device cards when devices available', (tester) async {
      await _pumpWithDevices(tester, [device1, device2]);

      expect(find.text('Pixel 7'), findsOneWidget);
      expect(find.text('Galaxy S23'), findsOneWidget);
      expect(find.text('abc123'), findsOneWidget);
      expect(find.text('def456'), findsOneWidget);
    });

    testWidgets('shows WhatsApp package chips on device cards',
        (tester) async {
      await _pumpWithDevices(tester, [device1]);

      expect(find.text('WhatsApp'), findsOneWidget);
    });

    testWidgets('can select source and dest devices', (tester) async {
      await _pumpWithDevices(tester, [device1, device2]);

      // Tap "Seleccionar como origen" on first card
      await tester.tap(find.text('Seleccionar como origen').first);
      await tester.pump();

      expect(find.text('Origen'), findsOneWidget);

      // Tap "Seleccionar como destino" on second card
      await tester.tap(find.text('Seleccionar como destino').last);
      await tester.pump();

      expect(find.text('Destino'), findsOneWidget);
    });

    testWidgets('Continue button disabled without selection', (tester) async {
      await _pumpWithDevices(tester, [device1, device2]);

      final continueButton = find.widgetWithText(
        FilledButton,
        'Continuar a selección de datos',
      );
      expect(continueButton, findsOneWidget);
      expect(
        tester.widget<FilledButton>(continueButton).onPressed,
        isNull,
      );
    });

    testWidgets('Continue button enabled with source and dest selected',
        (tester) async {
      final transport = _DeviceListTransport(devices: [device1, device2]);
      final client = BackendClient(transport: transport);
      final provider = DeviceProvider(DeviceService(client));

      await tester.pumpWidget(_wrapHomeScreen(provider));
      await tester.pump();

      // Select source and dest via provider (not UI tapping to keep test simple)
      provider.setSourceDevice(device1);
      provider.setDestDevice(device2);
      await tester.pump();

      provider.stopPolling();

      final continueButton = find.widgetWithText(
        FilledButton,
        'Continuar a selección de datos',
      );
      expect(
        tester.widget<FilledButton>(continueButton).onPressed,
        isNotNull,
      );
    });

    testWidgets('shows API level and classification on device cards',
        (tester) async {
      await _pumpWithDevices(tester, [device1, device2]);

      expect(find.text('API 33'), findsOneWidget);
      expect(find.text('API 29'), findsOneWidget);
    });

    testWidgets('shows empty state on refresh with no devices', (tester) async {
      await _pumpWithDevices(tester, []);

      expect(find.text('No se encontraron dispositivos'), findsOneWidget);
    });
  });
}
