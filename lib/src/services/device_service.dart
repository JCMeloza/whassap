import '../models/device.dart';
import 'backend_client.dart';

/// Service for device-related operations via the Python backend.
class DeviceService {
  final BackendClient _client;

  DeviceService(this._client);

  /// List all connected devices.
  Future<List<Device>> listDevices() async {
    final response = await _client.callMethod('device.list', {});
    if (response.error != null) {
      throw DeviceServiceException(response.error!.message);
    }

    final devicesJson = response.result?['devices'] as List<dynamic>? ?? [];
    return devicesJson
        .map((d) => Device.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  /// Get device properties via `adb shell getprop`.
  Future<Map<String, dynamic>> getProperties(String serial) async {
    final response = await _client.callMethod(
      'device.properties',
      {'serial': serial},
    );
    if (response.error != null) {
      throw DeviceServiceException(response.error!.message);
    }

    return response.result as Map<String, dynamic>? ?? {};
  }

  /// Detect WhatsApp packages on a device.
  Future<List<String>> detectPackages(String serial) async {
    final response = await _client.callMethod(
      'device.packages',
      {'serial': serial},
    );
    if (response.error != null) {
      throw DeviceServiceException(response.error!.message);
    }

    final packages = response.result?['packages'] as List<dynamic>? ?? [];
    return packages.map((p) => p as String).toList();
  }

  /// List only devices that have at least one WhatsApp variant installed.
  Future<List<Device>> listDevicesWithWhatsApp() async {
    final devices = await listDevices();
    return devices.where((d) => d.hasWhatsApp).toList();
  }
}

/// Exception thrown by [DeviceService] operations.
class DeviceServiceException implements Exception {
  final String message;
  DeviceServiceException(this.message);

  @override
  String toString() => 'DeviceServiceException: $message';
}
