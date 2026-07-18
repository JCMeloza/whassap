import 'package:flutter/foundation.dart';
import '../models/scan_result.dart';
import '../services/backend_client.dart';

/// Provides scan (data discovery) state to the widget tree.
///
/// Holds the [ScanResult] from backend device scanning, and manages
/// user selection of which packages and data types to transfer.
class ScanProvider extends ChangeNotifier {
  final BackendClient _client;

  ScanResult? _scanResult;
  bool _isScanning = false;
  bool _includeDatabases = true;
  bool _includeMedia = true;
  List<String> _selectedPackages = [];
  String? _errorMessage;

  ScanProvider(this._client);

  // ---- Getters ----

  ScanResult? get scanResult => _scanResult;
  bool get isScanning => _isScanning;
  bool get includeDatabases => _includeDatabases;
  bool get includeMedia => _includeMedia;
  List<String> get selectedPackages => List.unmodifiable(_selectedPackages);
  String? get errorMessage => _errorMessage;

  /// Total bytes of all selected packages and data types.
  int get totalBytes {
    if (_scanResult == null) return 0;
    int total = 0;
    for (final pkg in _scanResult!.packages) {
      if (!_selectedPackages.contains(pkg.package)) continue;
      if (_includeDatabases) {
        total += pkg.databases.fold<int>(0, (s, db) => s + db.sizeBytes);
      }
      if (_includeMedia) {
        total += pkg.media.fold<int>(0, (s, m) => s + m.sizeBytes);
      }
    }
    return total;
  }

  bool get canTransfer => totalBytes > 0 && _selectedPackages.isNotEmpty;

  // ---- Scanning ----

  /// Scan the specified device for WhatsApp data.
  Future<void> startScan(String serial) async {
    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.callMethod('scanner.scan', {
        'serial': serial,
        'packages': ['com.whatsapp', 'com.whatsapp.w4b'],
      });

      if (response.error != null) {
        _errorMessage = response.error!.message;
      } else {
        _scanResult =
            ScanResult.fromJson(response.result as Map<String, dynamic>);
        _selectedPackages =
            _scanResult!.packages.map((p) => p.package).toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isScanning = false;
    notifyListeners();
  }

  /// Raw bytes for a specific package.
  int packageBytes(PackageData pkg) {
    int total = 0;
    if (_includeDatabases) {
      total += pkg.databases.fold<int>(0, (s, db) => s + db.sizeBytes);
    }
    if (_includeMedia) {
      total += pkg.media.fold<int>(0, (s, m) => s + m.sizeBytes);
    }
    return total;
  }

  // ---- Selection toggles ----

  void toggleDatabases() {
    _includeDatabases = !_includeDatabases;
    notifyListeners();
  }

  void toggleMedia() {
    _includeMedia = !_includeMedia;
    notifyListeners();
  }

  void togglePackage(String package) {
    if (_selectedPackages.contains(package)) {
      _selectedPackages =
          _selectedPackages.where((p) => p != package).toList();
    } else {
      _selectedPackages = [..._selectedPackages, package];
    }
    notifyListeners();
  }

  bool isPackageSelected(String package) => _selectedPackages.contains(package);

  // ---- Reset ----

  void reset() {
    _scanResult = null;
    _isScanning = false;
    _includeDatabases = true;
    _includeMedia = true;
    _selectedPackages = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Directly set scan result (used in tests).
  void updateScanResult(ScanResult result) {
    _scanResult = result;
    _selectedPackages = result.packages.map((p) => p.package).toList();
    notifyListeners();
  }
}
