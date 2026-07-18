/// Status of a transfer operation.
enum TransferStatus { idle, transferring, paused, completed, failed, cancelled }

/// A single item being transferred (database file or media directory).
class TransferItem {
  final String package;
  final String path;
  final int bytesTotal;
  final int bytesTransferred;

  const TransferItem({
    required this.package,
    required this.path,
    required this.bytesTotal,
    required this.bytesTransferred,
  });

  double get percentage =>
      bytesTotal > 0 ? (bytesTransferred / bytesTotal) * 100 : 0.0;
}

/// Immutable state model for the current transfer.
class TransferState {
  final TransferStatus status;
  final String? transferId;
  final String? phase;
  final String? currentItem;
  final int bytesTransferred;
  final int bytesTotal;
  final double transferRateBps;
  final int etaSeconds;
  final String? errorMessage;
  final List<TransferItem> items;

  const TransferState({
    this.status = TransferStatus.idle,
    this.transferId,
    this.phase,
    this.currentItem,
    this.bytesTransferred = 0,
    this.bytesTotal = 0,
    this.transferRateBps = 0,
    this.etaSeconds = 0,
    this.errorMessage,
    this.items = const [],
  });

  double get percentage =>
      bytesTotal > 0 ? (bytesTransferred / bytesTotal) * 100 : 0.0;

  TransferState startTransfer({
    required String transferId,
    required List<TransferItem> items,
  }) {
    return TransferState(
      status: TransferStatus.transferring,
      transferId: transferId,
      phase: 'pull',
      items: items,
      bytesTotal: items.fold(0, (sum, item) => sum + item.bytesTotal),
    );
  }

  TransferState updateProgress({
    required int bytesTransferred,
    required int bytesTotal,
    required String? currentItem,
  }) {
    return TransferState(
      status: status,
      transferId: transferId,
      phase: phase,
      currentItem: currentItem,
      bytesTransferred: bytesTransferred,
      bytesTotal: bytesTotal,
      transferRateBps: transferRateBps,
      etaSeconds: etaSeconds,
      errorMessage: errorMessage,
      items: items,
    );
  }

  TransferState updatePhase(String newPhase) {
    return TransferState(
      status: status,
      transferId: transferId,
      phase: newPhase,
      currentItem: currentItem,
      bytesTransferred: bytesTransferred,
      bytesTotal: bytesTotal,
      transferRateBps: transferRateBps,
      etaSeconds: etaSeconds,
      errorMessage: errorMessage,
      items: items,
    );
  }

  TransferState updateTransferRateBps(double rate) {
    return TransferState(
      status: status,
      transferId: transferId,
      phase: phase,
      currentItem: currentItem,
      bytesTransferred: bytesTransferred,
      bytesTotal: bytesTotal,
      transferRateBps: rate,
      etaSeconds: etaSeconds,
      errorMessage: errorMessage,
      items: items,
    );
  }

  TransferState updateEtaSeconds(int eta) {
    return TransferState(
      status: status,
      transferId: transferId,
      phase: phase,
      currentItem: currentItem,
      bytesTransferred: bytesTransferred,
      bytesTotal: bytesTotal,
      transferRateBps: transferRateBps,
      etaSeconds: eta,
      errorMessage: errorMessage,
      items: items,
    );
  }

  TransferState pause() {
    return TransferState(
      status: TransferStatus.paused,
      transferId: transferId,
      phase: phase,
      currentItem: currentItem,
      bytesTransferred: bytesTransferred,
      bytesTotal: bytesTotal,
      transferRateBps: transferRateBps,
      etaSeconds: etaSeconds,
      errorMessage: errorMessage,
      items: items,
    );
  }

  TransferState resume() {
    return TransferState(
      status: TransferStatus.transferring,
      transferId: transferId,
      phase: phase,
      currentItem: currentItem,
      bytesTransferred: bytesTransferred,
      bytesTotal: bytesTotal,
      transferRateBps: transferRateBps,
      etaSeconds: etaSeconds,
      errorMessage: errorMessage,
      items: items,
    );
  }

  TransferState cancel() {
    return TransferState(
      status: TransferStatus.cancelled,
      transferId: transferId,
      phase: phase,
      currentItem: currentItem,
      bytesTransferred: bytesTransferred,
      bytesTotal: bytesTotal,
      errorMessage: errorMessage,
      items: items,
    );
  }

  TransferState complete() {
    return TransferState(
      status: TransferStatus.completed,
      transferId: transferId,
      phase: 'complete',
      bytesTransferred: bytesTotal,
      bytesTotal: bytesTotal,
      items: items,
    );
  }

  TransferState fail(String message) {
    return TransferState(
      status: TransferStatus.failed,
      transferId: transferId,
      phase: phase,
      currentItem: currentItem,
      bytesTransferred: bytesTransferred,
      bytesTotal: bytesTotal,
      errorMessage: message,
      items: items,
    );
  }

  TransferState reset() {
    return const TransferState();
  }
}
