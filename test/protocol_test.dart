import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_transfer/src/protocol/protocol.dart';

void main() {
  group('Request', () {
    test('creates request with required fields', () {
      final request = Request(
        id: 'test-id',
        method: 'device.list',
        params: {},
      );

      expect(request.type, 'request');
      expect(request.id, 'test-id');
      expect(request.method, 'device.list');
      expect(request.params, {});
    });

    test('serializes to JSON', () {
      final request = Request(
        id: 'uuid-123',
        method: 'device.list',
        params: {'serial': 'abc123'},
      );

      final json = jsonDecode(request.toJson());
      expect(json['type'], 'request');
      expect(json['id'], 'uuid-123');
      expect(json['method'], 'device.list');
      expect(json['params'], {'serial': 'abc123'});
    });

    test('deserializes from JSON string', () {
      final json = '{"type":"request","id":"r1","method":"transfer.pause","params":{"transferId":"t1"}}';
      final request = Request.fromJsonString(json);

      expect(request.type, 'request');
      expect(request.id, 'r1');
      expect(request.method, 'transfer.pause');
      expect(request.params, {'transferId': 't1'});
    });

    test('round-trip JSON', () {
      final original = Request(
        id: 'uuid-456',
        method: 'scanner.scan',
        params: {'serial': 'xyz', 'packages': ['com.whatsapp'], 'apiLevel': 29},
      );

      final rehydrated = Request.fromJsonString(original.toJson());
      expect(rehydrated.id, original.id);
      expect(rehydrated.method, original.method);
      expect(rehydrated.params, original.params);
    });
  });

  group('Response', () {
    test('creates success response', () {
      final response = Response.success(
        id: 'r1',
        result: {'devices': []},
      );

      expect(response.type, 'response');
      expect(response.id, 'r1');
      expect(response.result, {'devices': []});
      expect(response.error, isNull);
    });

    test('creates error response', () {
      final response = Response.error(
        id: 'r1',
        code: 'DEVICE_NOT_FOUND',
        message: 'Device not found',
      );

      expect(response.type, 'response');
      expect(response.id, 'r1');
      expect(response.result, isNull);
      expect(response.error, isA<ProtocolError>());
      expect(response.error!.code, 'DEVICE_NOT_FOUND');
      expect(response.error!.message, 'Device not found');
    });

    test('serializes success to JSON', () {
      final response = Response.success(
        id: 'r1',
        result: {'devices': [{'serial': 'abc'}]},
      );

      final json = jsonDecode(response.toJson());
      expect(json['type'], 'response');
      expect(json['id'], 'r1');
      expect(json['result']['devices'][0]['serial'], 'abc');
      expect(json.containsKey('error'), false);
    });

    test('serializes error to JSON', () {
      final response = Response.error(id: 'r1', code: 'ERR', message: 'fail');

      final json = jsonDecode(response.toJson());
      expect(json['type'], 'response');
      expect(json['id'], 'r1');
      expect(json['error']['code'], 'ERR');
      expect(json['error']['message'], 'fail');
      expect(json.containsKey('result'), false);
    });

    test('deserializes from JSON string (success)', () {
      final json = '{"type":"response","id":"r1","result":{"done":true}}';
      final response = Response.fromJsonString(json);

      expect(response.id, 'r1');
      expect(response.result, {'done': true});
      expect(response.error, isNull);
    });

    test('deserializes from JSON string (error)', () {
      final json = '{"type":"response","id":"r1","error":{"code":"ERR","message":"fail"}}';
      final response = Response.fromJsonString(json);

      expect(response.id, 'r1');
      expect(response.result, isNull);
      expect(response.error!.code, 'ERR');
      expect(response.error!.message, 'fail');
    });
  });

  group('ProgressEvent', () {
    test('creates progress event', () {
      final event = ProgressEvent(
        transferId: 't1',
        phase: 'pull',
        package: 'com.whatsapp',
        item: 'Databases/msgstore.db.crypt14',
        bytesTransferred: 1000000,
        bytesTotal: 5000000000,
        percentage: 0.02,
        transferRateBps: 12000000,
        etaSeconds: 400,
      );

      expect(event.type, 'progress');
      expect(event.transferId, 't1');
      expect(event.phase, 'pull');
      expect(event.item, 'Databases/msgstore.db.crypt14');
    });

    test('serializes to JSON', () {
      final event = ProgressEvent(
        transferId: 't1',
        phase: 'push',
        package: 'com.whatsapp.w4b',
        item: 'Media/Images/',
        bytesTransferred: 500000,
        bytesTotal: 2000000,
        percentage: 25.0,
        transferRateBps: 5000000,
        etaSeconds: 300,
      );

      final json = jsonDecode(event.toJson());
      expect(json['type'], 'progress');
      expect(json['phase'], 'push');
      expect(json['percentage'], 25.0);
      expect(json['etaSeconds'], 300);
    });

    test('deserializes from JSON string', () {
      final json = '{"type":"progress","transferId":"t1","phase":"pull",'
          '"package":"com.whatsapp","item":"test.db",'
          '"bytesTransferred":100,"bytesTotal":1000,"percentage":10.0,'
          '"transferRateBps":50000,"etaSeconds":20}';
      final event = ProgressEvent.fromJsonString(json);

      expect(event.transferId, 't1');
      expect(event.phase, 'pull');
      expect(event.bytesTransferred, 100);
      expect(event.bytesTotal, 1000);
      expect(event.percentage, 10.0);
      expect(event.etaSeconds, 20);
    });
  });

  group('PhaseChangeEvent', () {
    test('creates phase change event', () {
      final event = PhaseChangeEvent(
        transferId: 't1',
        fromPhase: 'pull',
        toPhase: 'push',
      );

      expect(event.type, 'phase_change');
      expect(event.transferId, 't1');
      expect(event.fromPhase, 'pull');
      expect(event.toPhase, 'push');
    });

    test('serializes to JSON', () {
      final event = PhaseChangeEvent(
        transferId: 't1',
        fromPhase: 'push',
        toPhase: 'complete',
      );

      final json = jsonDecode(event.toJson());
      expect(json['type'], 'phase_change');
      expect(json['from'], 'push');
      expect(json['to'], 'complete');
    });

    test('deserializes from JSON string', () {
      final json = '{"type":"phase_change","transferId":"t1","from":"pull","to":"push"}';
      final event = PhaseChangeEvent.fromJsonString(json);

      expect(event.transferId, 't1');
      expect(event.fromPhase, 'pull');
      expect(event.toPhase, 'push');
    });
  });

  group('BackendEvent', () {
    test('creates backend event', () {
      final event = BackendEvent(
        event: 'adb_info',
        data: {'path': '/usr/bin/adb', 'version': '34.0.5', 'source': 'system'},
      );

      expect(event.type, 'event');
      expect(event.event, 'adb_info');
      expect(event.data['version'], '34.0.5');
    });

    test('deserializes from JSON string', () {
      final json = '{"type":"event","event":"driver_issue","data":{"message":"USB driver missing"}}';
      final event = BackendEvent.fromJsonString(json);

      expect(event.event, 'driver_issue');
      expect(event.data['message'], 'USB driver missing');
    });
  });

  group('ProtocolMessage parse', () {
    test('parses request from JSON line', () {
      final parsed = ProtocolMessage.parse(
        '{"type":"request","id":"r1","method":"device.list","params":{}}',
      );

      expect(parsed, isA<Request>());
      final req = parsed as Request;
      expect(req.id, 'r1');
      expect(req.method, 'device.list');
    });

    test('parses response from JSON line', () {
      final parsed = ProtocolMessage.parse(
        '{"type":"response","id":"r1","result":{"devices":[]}}',
      );

      expect(parsed, isA<Response>());
      final resp = parsed as Response;
      expect(resp.result, {'devices': []});
    });

    test('parses progress event from JSON line', () {
      final parsed = ProtocolMessage.parse(
        '{"type":"progress","transferId":"t1","phase":"pull","package":"com.whatsapp",'
        '"item":"f","bytesTransferred":0,"bytesTotal":1,"percentage":0.0,'
        '"transferRateBps":0,"etaSeconds":0}',
      );

      expect(parsed, isA<ProgressEvent>());
    });

    test('parses phase change event from JSON line', () {
      final parsed = ProtocolMessage.parse(
        '{"type":"phase_change","transferId":"t1","from":"pull","to":"push"}',
      );

      expect(parsed, isA<PhaseChangeEvent>());
    });

    test('parses backend event from JSON line', () {
      final parsed = ProtocolMessage.parse(
        '{"type":"event","event":"adb_info","data":{}}',
      );

      expect(parsed, isA<BackendEvent>());
    });

    test('throws on unknown type', () {
      expect(
        () => ProtocolMessage.parse('{"type":"unknown"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on invalid JSON', () {
      expect(
        () => ProtocolMessage.parse('not json'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ProtocolError', () {
    test('creates with required fields', () {
      final error = ProtocolError(code: 'TEST_ERROR', message: 'Test message');
      expect(error.code, 'TEST_ERROR');
      expect(error.message, 'Test message');
    });
  });
}
