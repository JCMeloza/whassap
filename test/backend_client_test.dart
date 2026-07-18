import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_transfer/src/services/backend_client.dart';
import 'package:whatsapp_transfer/src/protocol/protocol.dart';

/// A mock transport that simulates stdin/stdout pipes without spawning a process.
class MockTransport extends BackendTransport {
  final _outgoing = StreamController<List<int>>();
  final _incoming = StreamController<List<int>>();
  final List<String> _sentLines = [];

  @override
  Stream<List<int>> get stdout => _outgoing.stream;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  void addStdin(List<int> data) {
    _sentLines.add(utf8.decode(data).trim());
  }

  @override
  Future<void> close() async {
    await _incoming.close();
    await _outgoing.close();
  }

  /// Simulate receiving a JSON line from the backend.
  void emitLine(String line) {
    _incoming.add(utf8.encode('$line\n'));
  }

  /// Simulate receiving multiple lines.
  void emitLines(List<String> lines) {
    for (final line in lines) {
      emitLine(line);
    }
  }

  /// The lines sent via addStdin.
  List<String> get sentLines => List.unmodifiable(_sentLines);

  /// Start the transport (simulate process start).
  void start() {
    // Bind the incoming controller to outgoing: incoming data from "backend"
    // flows out through the stdout stream.
    _outgoing.addStream(_incoming.stream);
  }

  @override
  Future<int> get exitCode => Future.value(0);
}

void main() {
  late MockTransport transport;
  late BackendClient client;

  setUp(() {
    transport = MockTransport();
    client = BackendClient(transport: transport);
    transport.start();
  });

  tearDown(() async {
    await client.dispose();
  });

  group('BackendClient', () {
    test('sends JSON request to stdin', () async {
      final request = Request(id: 'r1', method: 'device.list', params: {});
      final future = client.sendRequest(request);

      // Simulate response from backend
      transport.emitLine(
        '{"type":"response","id":"r1","result":{"devices":[]}}',
      );

      final response = await future;
      expect(response.result, {'devices': []});
      expect(transport.sentLines.length, 1);

      final sent = jsonDecode(transport.sentLines.first);
      expect(sent['type'], 'request');
      expect(sent['id'], 'r1');
      expect(sent['method'], 'device.list');
    });

    test('correlates response by ID with multiple concurrent requests',
        () async {
      final req1 = Request(id: 'id1', method: 'device.list', params: {});
      final req2 = Request(id: 'id2', method: 'device.packages', params: {});

      final fut1 = client.sendRequest(req1);
      final fut2 = client.sendRequest(req2);

      // Send responses out of order
      transport.emitLine(
        '{"type":"response","id":"id2","result":{"packages":["com.whatsapp"]}}',
      );
      transport.emitLine(
        '{"type":"response","id":"id1","result":{"devices":[]}}',
      );

      final resp2 = await fut2;
      final resp1 = await fut1;

      expect(resp2.result['packages'], ['com.whatsapp']);
      expect(resp1.result['devices'], []);
    });

    test('handles error response', () async {
      final request = Request(id: 'e1', method: 'device.list', params: {});
      final future = client.sendRequest(request);

      transport.emitLine(
        '{"type":"response","id":"e1","error":{"code":"NOT_FOUND","message":"No devices"}}',
      );

      final response = await future;
      expect(response.result, isNull);
      expect(response.error, isNotNull);
      expect(response.error!.code, 'NOT_FOUND');
    });

    test('streams progress events', () async {
      final progressEvents = <ProgressEvent>[];
      final sub = client.progressStream.listen((event) {
        progressEvents.add(event);
      });

      transport.emitLine(
        '{"type":"progress","transferId":"t1","phase":"pull","package":"com.whatsapp",'
        '"item":"db1","bytesTransferred":0,"bytesTotal":100,"percentage":0.0,'
        '"transferRateBps":0,"etaSeconds":0}',
      );
      transport.emitLine(
        '{"type":"progress","transferId":"t1","phase":"pull","package":"com.whatsapp",'
        '"item":"db1","bytesTransferred":50,"bytesTotal":100,"percentage":50.0,'
        '"transferRateBps":1000,"etaSeconds":30}',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(progressEvents.length, 2);
      expect(progressEvents[0].bytesTransferred, 0);
      expect(progressEvents[1].bytesTransferred, 50);
      expect(progressEvents[1].percentage, 50.0);
    });

    test('streams phase change events', () async {
      final events = <PhaseChangeEvent>[];
      final sub = client.phaseChangeStream.listen((event) {
        events.add(event);
      });

      transport.emitLine(
        '{"type":"phase_change","transferId":"t1","from":"pull","to":"push"}',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(events.length, 1);
      expect(events[0].fromPhase, 'pull');
      expect(events[0].toPhase, 'push');
    });

    test('streams backend events', () async {
      final events = <BackendEvent>[];
      final sub = client.backendEventStream.listen((event) {
        events.add(event);
      });

      transport.emitLine(
        '{"type":"event","event":"adb_info","data":{"version":"34.0.5"}}',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(events.length, 1);
      expect(events[0].event, 'adb_info');
      expect(events[0].data['version'], '34.0.5');
    });

    test('ignores lines that cannot be parsed', () async {
      final progressEvents = <ProgressEvent>[];
      final sub = client.progressStream.listen((event) {
        progressEvents.add(event);
      });

      // Invalid JSON should be ignored
      transport.emitLine('not json');
      // Valid progress event should still come through
      transport.emitLine(
        '{"type":"progress","transferId":"t1","phase":"pull","package":"com.whatsapp",'
        '"item":"db1","bytesTransferred":10,"bytesTotal":100,"percentage":10.0,'
        '"transferRateBps":0,"etaSeconds":0}',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(progressEvents.length, 1);
      expect(progressEvents[0].bytesTransferred, 10);
    });

    test('convenience method sendRequestString works', () async {
      final future = client.sendRequestString(
        '{"type":"request","id":"r1","method":"device.list","params":{}}',
      );

      transport.emitLine(
        '{"type":"response","id":"r1","result":{"ok":true}}',
      );

      final response = await future;
      expect(response.result, {'ok': true});
    });
  });
}
