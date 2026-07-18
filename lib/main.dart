import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/app.dart';
import 'src/providers/device_provider.dart';
import 'src/providers/transfer_provider.dart';
import 'src/providers/scan_provider.dart';
import 'src/services/backend_client.dart';
import 'src/services/device_service.dart';
import 'src/services/transfer_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final backendClient = BackendClient();
  final deviceService = DeviceService(backendClient);
  final transferService = TransferService(backendClient);

  // Non-blocking backend spawn — app works in dev mode without backend
  _trySpawnBackend(backendClient);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider(deviceService)),
        ChangeNotifierProvider(create: (_) => TransferProvider(transferService)),
        ChangeNotifierProvider(create: (_) => ScanProvider(backendClient)),
      ],
      child: const WhatsAppTransferApp(),
    ),
  );
}

Future<void> _trySpawnBackend(BackendClient client) async {
  try {
    // Dev mode: spawn python3 -m backend.main from project root
    // Production: use the bundled PyInstaller binary path
    await client.spawnProcess('python3', args: ['-m', 'backend.main']);
  } catch (_) {
    // Backend not available — app runs in mock/dev mode
  }
}
