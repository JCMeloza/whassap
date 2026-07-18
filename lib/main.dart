import 'dart:io';

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
    final backend = _resolveBackend();
    if (backend.bundled) {
      // Production: spawn the bundled PyInstaller binary directly
      await client.spawnProcess(backend.path);
    } else {
      // Dev mode: spawn python3 -m backend.main
      await client.spawnProcess(backend.path, args: ['-m', 'backend.main']);
    }
  } catch (_) {
    // Backend not available — app runs in mock/dev mode
  }
}

({String path, bool bundled}) _resolveBackend() {
  // 1) Check for bundled binary next to the Flutter executable
  try {
    final bundleDir = File(Platform.resolvedExecutable).parent.path;
    final bundledBackend = '$bundleDir/whatsapp-backend';
    final file = File(bundledBackend);
    if (file.existsSync() && file.statSync().size > 0) {
      return (path: bundledBackend, bundled: true);
    }
  } catch (_) {
    // Fall through
  }

  // 2) Dev mode: prefer venv python
  const venvPython = '.venv/bin/python3';
  try {
    final file = File(venvPython);
    if (file.existsSync() && file.statSync().size > 0) {
      return (path: venvPython, bundled: false);
    }
  } catch (_) {
    // Fall through
  }

  // 3) Fallback to system python
  return (path: 'python3', bundled: false);
}
