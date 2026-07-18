import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_transfer/src/models/transfer.dart';
import 'package:whatsapp_transfer/src/services/transfer_service.dart';
import 'package:whatsapp_transfer/src/services/backend_client.dart';
import 'package:whatsapp_transfer/src/protocol/protocol.dart';

/// Transport that responds to requests and emits events after the response.
class MockTransferTransport extends BackendTransport {
  final _outgoing = StreamController<List<int>>();
  final List<String> _eventsAfterResponse;

  MockTransferTransport({
    List<String> eventsAfterResponse = const [],
  }) : _eventsAfterResponse = eventsAfterResponse;

  @override
  Stream<List<int>> get stdout => _outgoing.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  void addStdin(List<int> data) {
    final sent = utf8.decode(data).trim();
    final reqJson = jsonDecode(sent) as Map<String, dynamic>;
    final reqId = reqJson['id'] as String;
    final method = reqJson['method'] as String;

    // Emit response first
    final response = _makeResponse(reqId, method);
    _outgoing.add(utf8.encode('${jsonEncode(response)}\n'));

    // Then schedule events to arrive after response is processed
    if (_eventsAfterResponse.isNotEmpty) {
      Future.microtask(() {
        for (final event in _eventsAfterResponse) {
          _outgoing.add(utf8.encode('$event\n'));
        }
      });
    }
  }

  Map<String, dynamic> _makeResponse(String id, String method) {
    switch (method) {
      case 'transfer.start':
        return {'type': 'response', 'id': id, 'result': {'transferId': 't-uuid-123'}};
      case 'transfer.pause':
        return {'type': 'response', 'id': id, 'result': {'status': 'paused'}};
      case 'transfer.resume':
        return {'type': 'response', 'id': id, 'result': {'status': 'resumed'}};
      case 'transfer.cancel':
        return {'type': 'response', 'id': id, 'result': {'status': 'cancelled'}};
      default:
        return {'type': 'response', 'id': id, 'result': {}};
    }
  }

  @override
  Future<void> close() async { await _outgoing.close(); }
  @override
  Future<int> get exitCode => Future.value(0);
}

void main() {
  group('TransferService', () {
    test('startTransfer sends request and returns TransferState', () async {
      final transport = MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);

      expect(service.state.status, TransferStatus.idle);

      final state = await service.startTransfer(
        sourceSerial: 'src-abc',
        destSerial: 'dst-def',
        packages: ['com.whatsapp'],
        items: ['Databases/msgstore.db.crypt14', 'Media/Images/'],
      );

      expect(state.status, TransferStatus.transferring);
      expect(state.transferId, 't-uuid-123');
      expect(state.phase, 'pull');
      await client.dispose();
    });

    test('pauseTransfer sends request and updates state', () async {
      final transport = MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);

      service.updateState(service.state.startTransfer(transferId: 't1', items: []));

      final state = await service.pauseTransfer();
      expect(state.status, TransferStatus.paused);
      await client.dispose();
    });

    test('resumeTransfer sends request and updates state', () async {
      final transport = MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);

      service.updateState(service.state.startTransfer(transferId: 't1', items: []).pause());

      final state = await service.resumeTransfer();
      expect(state.status, TransferStatus.transferring);
      await client.dispose();
    });

    test('cancelTransfer sends request and updates state', () async {
      final transport = MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);

      service.updateState(service.state.startTransfer(transferId: 't1', items: []));

      final state = await service.cancelTransfer();
      expect(state.status, TransferStatus.cancelled);
      await client.dispose();
    });

    test('handles progress events during transfer', () async {
      final transport = MockTransferTransport(
        eventsAfterResponse: [
          jsonEncode({
            'type': 'progress', 'transferId': 't-uuid-123', 'phase': 'pull',
            'package': 'com.whatsapp', 'item': 'db1',
            'bytesTransferred': 500, 'bytesTotal': 1000, 'percentage': 50.0,
            'transferRateBps': 1000000, 'etaSeconds': 30,
          }),
        ],
      );
      final client = BackendClient(transport: transport);
      final service = TransferService(client);

      await service.startTransfer(
        sourceSerial: 'src', destSerial: 'dst',
        packages: ['com.whatsapp'], items: ['db1'],
      );

      // Wait for microtask to emit events
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.state.phase, 'pull');
      expect(service.state.bytesTransferred, 500);
      expect(service.state.bytesTotal, 1000);
      await client.dispose();
    });

    test('handles phase change event', () async {
      final transport = MockTransferTransport(
        eventsAfterResponse: [
          jsonEncode({
            'type': 'phase_change', 'transferId': 't-uuid-123',
            'from': 'pull', 'to': 'push',
          }),
        ],
      );
      final client = BackendClient(transport: transport);
      final service = TransferService(client);

      await service.startTransfer(
        sourceSerial: 'src', destSerial: 'dst',
        packages: ['com.whatsapp'], items: ['db1'],
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.state.phase, 'push');
      await client.dispose();
    });

    test('resetTransfer restores idle state', () async {
      final transport = MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);

      service.updateState(service.state.startTransfer(transferId: 't1', items: []));
      expect(service.state.status, TransferStatus.transferring);

      service.resetTransfer();
      expect(service.state.status, TransferStatus.idle);
      await client.dispose();
    });

    test('state stream emits on state changes', () async {
      final transport = MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);

      final states = <TransferState>[];
      final sub = service.stateStream.listen((s) => states.add(s));

      service.updateState(service.state.startTransfer(transferId: 't1', items: []));

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states.length, 1);
      expect(states[0].status, TransferStatus.transferring);

      await sub.cancel();
      await client.dispose();
    });
  });
}
