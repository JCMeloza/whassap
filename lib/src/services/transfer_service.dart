import 'dart:async';

import '../models/transfer.dart';
import '../protocol/protocol.dart';
import 'backend_client.dart';

/// Service for transfer orchestration via the Python backend.
class TransferService {
  final BackendClient _client;
  TransferState _state = const TransferState();
  final _stateController = StreamController<TransferState>.broadcast();
  StreamSubscription<ProgressEvent>? _progressSub;
  StreamSubscription<PhaseChangeEvent>? _phaseSub;

  TransferService(this._client) {
    _listenToEvents();
  }

  /// Current transfer state.
  TransferState get state => _state;

  /// Stream of state changes.
  Stream<TransferState> get stateStream => _stateController.stream;

  void _listenToEvents() {
    _progressSub = _client.progressStream.listen(_handleProgress);
    _phaseSub = _client.phaseChangeStream.listen(_handlePhaseChange);
  }

  void _handleProgress(ProgressEvent event) {
    // Only process events for the current transfer
    if (event.transferId != _state.transferId) return;

    _updateAndNotify(
      _state.updateProgress(
        bytesTransferred: event.bytesTransferred,
        bytesTotal: event.bytesTotal,
        currentItem: event.item,
      ).updateTransferRateBps(event.transferRateBps)
       .updateEtaSeconds(event.etaSeconds),
    );
  }

  void _handlePhaseChange(PhaseChangeEvent event) {
    if (event.transferId != _state.transferId) return;

    _updateAndNotify(_state.updatePhase(event.toPhase));

    // If phase changed to "complete", mark as completed
    if (event.toPhase == 'complete') {
      _updateAndNotify(_state.complete());
    }
  }

  /// Start a new transfer.
  Future<TransferState> startTransfer({
    required String sourceSerial,
    required String destSerial,
    required List<String> packages,
    required List<String> items,
  }) async {
    final response = await _client.callMethod('transfer.start', {
      'source': sourceSerial,
      'dest': destSerial,
      'packages': packages,
      'items': items,
    });

    if (response.error != null) {
      _updateAndNotify(_state.fail(response.error!.message));
      return _state;
    }

    final transferId = response.result?['transferId'] as String? ?? '';
    final transferItems = items
        .map((item) => TransferItem(
              package: packages.isNotEmpty ? packages.first : '',
              path: item,
              bytesTotal: 0,
              bytesTransferred: 0,
            ))
        .toList();

    _updateAndNotify(_state.startTransfer(
      transferId: transferId,
      items: transferItems,
    ));
    return _state;
  }

  /// Pause the current transfer.
  Future<TransferState> pauseTransfer() async {
    if (_state.transferId == null) return _state;

    await _client.callMethod('transfer.pause', {
      'transferId': _state.transferId,
    });

    _updateAndNotify(_state.pause());
    return _state;
  }

  /// Resume the current transfer.
  Future<TransferState> resumeTransfer() async {
    if (_state.transferId == null) return _state;

    await _client.callMethod('transfer.resume', {
      'transferId': _state.transferId,
    });

    _updateAndNotify(_state.resume());
    return _state;
  }

  /// Cancel the current transfer.
  Future<TransferState> cancelTransfer() async {
    if (_state.transferId == null) return _state;

    await _client.callMethod('transfer.cancel', {
      'transferId': _state.transferId,
    });

    _updateAndNotify(_state.cancel());
    return _state;
  }

  /// Reset transfer state to idle.
  void resetTransfer() {
    _updateAndNotify(_state.reset());
  }

  /// Directly update the state (used for testing and external mutations).
  void updateState(TransferState newState) {
    _updateAndNotify(newState);
  }

  void _updateAndNotify(TransferState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Dispose of subscriptions.
  void dispose() {
    _progressSub?.cancel();
    _phaseSub?.cancel();
    _stateController.close();
  }
}
