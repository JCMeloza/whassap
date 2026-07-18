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
    // Dev mode: prefer venv python (where backend is installed via pip install -e .),
    // fall back to system python for bundled/custom setups.
    // Production: use the bundled PyInstaller binary path instead.
    final pythonPath = await _resolvePython();
    await client.spawnProcess(pythonPath, args: ['-m', 'backend.main']);
  } catch (_) {
    // Backend not available — app runs in mock/dev mode
  }
}

Future<String> _resolvePython() async {
  const venvPython = '.venv/bin/python3';
  try {
    // Check if .venv exists and has a working python
    final file = await File(venvPython).stat();
    if (file.size > 0) return venvPython;
  } catch (_) {
    // .venv not found, fall through to system python
  }
  return 'python3';
}
