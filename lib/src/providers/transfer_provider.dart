import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/transfer.dart';
import '../services/transfer_service.dart';

/// Provides transfer state to the widget tree.
///
/// Wraps [TransferService] and exposes [TransferState] reactively
/// via [ChangeNotifier]. Screens consume this to render progress UI.
class TransferProvider extends ChangeNotifier {
  final TransferService _transferService;
  StreamSubscription<TransferState>? _stateSub;

  TransferState _state = const TransferState();

  TransferProvider(this._transferService) {
    _stateSub = _transferService.stateStream.listen(_onStateChanged);
  }

  // ---- Getters ----

  TransferState get state => _state;
  TransferStatus get status => _state.status;
  String? get phase => _state.phase;
  double get percentage => _state.percentage;
  int get bytesTransferred => _state.bytesTransferred;
  int get bytesTotal => _state.bytesTotal;
  double get transferRateBps => _state.transferRateBps;
  int get etaSeconds => _state.etaSeconds;
  String? get currentItem => _state.currentItem;
  String? get errorMessage => _state.errorMessage;
  String? get transferId => _state.transferId;

  bool get isTransferring => _state.status == TransferStatus.transferring;
  bool get isPaused => _state.status == TransferStatus.paused;
  bool get isCompleted => _state.status == TransferStatus.completed;
  bool get isFailed => _state.status == TransferStatus.failed;
  bool get isCancelled => _state.status == TransferStatus.cancelled;
  bool get isIdle => _state.status == TransferStatus.idle;

  /// Formatted transfer rate for display (e.g., "12.3 MB/s").
  String get formattedRate {
    if (_state.transferRateBps <= 0) return '--';
    final mbps = _state.transferRateBps / (1024 * 1024);
    if (mbps >= 1) {
      return '${mbps.toStringAsFixed(1)} MB/s';
    }
    final kbps = _state.transferRateBps / 1024;
    return '${kbps.toStringAsFixed(1)} KB/s';
  }

  /// Formatted ETA for display (e.g., "2m 30s restante").
  String get formattedEta {
    if (_state.etaSeconds <= 0) return '--';
    final minutes = _state.etaSeconds ~/ 60;
    final seconds = _state.etaSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s restante';
    }
    return '${seconds}s restante';
  }

  /// Formatted bytes for display.
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  // ---- State management ----

  void _onStateChanged(TransferState state) {
    _state = state;
    notifyListeners();
  }

  Future<void> startTransfer({
    required String sourceSerial,
    required String destSerial,
    required List<String> packages,
    required List<String> items,
  }) async {
    await _transferService.startTransfer(
      sourceSerial: sourceSerial,
      destSerial: destSerial,
      packages: packages,
      items: items,
    );
  }

  Future<void> pauseTransfer() async {
    await _transferService.pauseTransfer();
  }

  Future<void> resumeTransfer() async {
    await _transferService.resumeTransfer();
  }

  Future<void> cancelTransfer() async {
    await _transferService.cancelTransfer();
  }

  void resetTransfer() {
    _transferService.resetTransfer();
  }

  /// Directly set state (used in tests).
  void updateState(TransferState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }
}
