import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../services/device_service.dart';

/// Provides device detection state to the widget tree.
///
/// Wraps [DeviceService] with polling, source/destination selection,
/// and error handling. Designed to be consumed via Provider's [ChangeNotifierProvider].
class DeviceProvider extends ChangeNotifier {
  final DeviceService _deviceService;
  Timer? _pollTimer;

  List<Device> _devices = [];
  Device? _sourceDevice;
  Device? _destDevice;
  bool _isPolling = false;
  bool _isLoading = false;
  String? _errorMessage;

  DeviceProvider(this._deviceService);

  // ---- Getters ----

  List<Device> get devices => List.unmodifiable(_devices);
  Device? get sourceDevice => _sourceDevice;
  Device? get destDevice => _destDevice;
  bool get isPolling => _isPolling;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get canContinue =>
      _sourceDevice != null &&
      _destDevice != null &&
      _sourceDevice!.serial != _destDevice!.serial;

  // ---- Selection ----

  bool isSource(Device device) => _sourceDevice?.serial == device.serial;
  bool isDest(Device device) => _destDevice?.serial == device.serial;

  /// Select a device as source or destination.
  /// Tapping an already-selected role deselects it.
  void selectDevice(Device device, {required bool asSource}) {
    if (asSource) {
      if (isSource(device)) {
        _sourceDevice = null;
      } else {
        _sourceDevice = device;
        if (_destDevice?.serial == device.serial) _destDevice = null;
      }
    } else {
      if (isDest(device)) {
        _destDevice = null;
      } else {
        _destDevice = device;
        if (_sourceDevice?.serial == device.serial) _sourceDevice = null;
      }
    }
    notifyListeners();
  }

  void setSourceDevice(Device? device) {
    _sourceDevice = device;
    if (device != null && _destDevice?.serial == device.serial) {
      _destDevice = null;
    }
    notifyListeners();
  }

  void setDestDevice(Device? device) {
    _destDevice = device;
    if (device != null && _sourceDevice?.serial == device.serial) {
      _sourceDevice = null;
    }
    notifyListeners();
  }

  // ---- Polling ----

  /// Start 2-second polling for device detection.
  ///
  /// The timer is established synchronously so [dispose] can always cancel it.
  /// The first refresh fires asynchronously (fire-and-forget).
  void startPolling() {
    if (_isPolling) return;
    _isPolling = true;
    notifyListeners();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      refreshDevices();
    });
    refreshDevices(); // immediate refresh, fire-and-forget
  }

  /// Stop polling.
  void stopPolling() {
    _isPolling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    notifyListeners();
  }

  /// Fetch device list from backend.
  Future<void> refreshDevices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _devices = await _deviceService.listDevices();
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  // ---- Test helpers (direct state manipulation) ----

  /// Directly set device list (used in tests and pre-population).
  void updateDevices(List<Device> devices) {
    _devices = devices;
    notifyListeners();
  }

  void updateError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
