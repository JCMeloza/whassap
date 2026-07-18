import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_transfer/src/models/transfer.dart';

void main() {
  group('TransferItem', () {
    test('creates with required fields', () {
      final item = TransferItem(
        package: 'com.whatsapp',
        path: 'Databases/msgstore.db.crypt14',
        bytesTotal: 50000000,
        bytesTransferred: 0,
      );

      expect(item.package, 'com.whatsapp');
      expect(item.path, 'Databases/msgstore.db.crypt14');
      expect(item.bytesTotal, 50000000);
      expect(item.bytesTransferred, 0);
    });

    test('percentage returns 0 when bytesTotal is 0', () {
      final item = TransferItem(
        package: 'com.whatsapp',
        path: 'empty',
        bytesTotal: 0,
        bytesTransferred: 0,
      );
      expect(item.percentage, 0.0);
    });

    test('percentage calculates correctly', () {
      final item = TransferItem(
        package: 'com.whatsapp',
        path: 'test',
        bytesTotal: 1000,
        bytesTransferred: 250,
      );
      expect(item.percentage, 25.0);
    });
  });

  group('TransferState', () {
    test('initial state is idle', () {
      final state = TransferState();
      expect(state.status, TransferStatus.idle);
      expect(state.phase, isNull);
      expect(state.transferId, isNull);
      expect(state.items, isEmpty);
    });

    test('starts transfer correctly', () {
      final state = TransferState().startTransfer(
        transferId: 't1',
        items: [
          TransferItem(package: 'com.whatsapp', path: 'db1', bytesTotal: 1000, bytesTransferred: 0),
        ],
      );

      expect(state.status, TransferStatus.transferring);
      expect(state.transferId, 't1');
      expect(state.items.length, 1);
      expect(state.phase, 'pull');
    });

    test('updates progress correctly', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [
            TransferItem(package: 'com.whatsapp', path: 'db1', bytesTotal: 1000, bytesTransferred: 0),
          ])
          .updateProgress(
            bytesTransferred: 500,
            bytesTotal: 1000,
            currentItem: 'db1',
          );

      expect(state.bytesTransferred, 500);
      expect(state.bytesTotal, 1000);
      expect(state.currentItem, 'db1');
    });

    test('percentage is 0 when bytesTotal is 0', () {
      final state = TransferState().startTransfer(transferId: 't1', items: []);
      expect(state.percentage, 0.0);
    });

    test('percentage calculates from bytes', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [])
          .updateProgress(bytesTransferred: 250, bytesTotal: 1000, currentItem: null);

      expect(state.percentage, 25.0);
    });

    test('pause sets status correctly', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [])
          .pause();

      expect(state.status, TransferStatus.paused);
      expect(state.transferId, 't1');
    });

    test('resume sets status correctly', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [])
          .pause()
          .resume();

      expect(state.status, TransferStatus.transferring);
    });

    test('cancel sets status correctly', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [])
          .cancel();

      expect(state.status, TransferStatus.cancelled);
    });

    test('complete sets status correctly', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [
            TransferItem(package: 'com.whatsapp', path: 'db1', bytesTotal: 1000, bytesTransferred: 1000),
          ])
          .complete();

      expect(state.status, TransferStatus.completed);
    });

    test('fail sets status and error', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [])
          .fail('ADB connection lost');

      expect(state.status, TransferStatus.failed);
      expect(state.errorMessage, 'ADB connection lost');
    });

    test('updatePhase changes phase', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [])
          .updatePhase('push');

      expect(state.phase, 'push');
    });

    test('updateTransferRateBps sets rate', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [])
          .updateTransferRateBps(12000000);

      expect(state.transferRateBps, 12000000);
    });

    test('updateEtaSeconds sets ETA', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [])
          .updateEtaSeconds(300);

      expect(state.etaSeconds, 300);
    });

    test('reset returns to idle', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [])
          .reset();

      expect(state.status, TransferStatus.idle);
      expect(state.transferId, isNull);
      expect(state.items, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('multiple status transitions', () {
      final state = TransferState()
          .startTransfer(transferId: 't1', items: [])
          .pause()
          .resume()
          .pause()
          .resume()
          .cancel();

      expect(state.status, TransferStatus.cancelled);
    });
  });
}
