import 'dart:convert';

/// Base class for all NDJSON protocol messages.
sealed class ProtocolMessage {
  String get type;

  /// Parse a JSON line into a typed protocol message.
  static ProtocolMessage parse(String line) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(line) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid JSON: $e', line);
    }

    final type = json['type'] as String?;
    if (type == null) {
      throw FormatException('Missing "type" field', line);
    }

    switch (type) {
      case 'request':
        return Request.fromJson(json);
      case 'response':
        return Response.fromJson(json);
      case 'progress':
        return ProgressEvent.fromJson(json);
      case 'phase_change':
        return PhaseChangeEvent.fromJson(json);
      case 'event':
        return BackendEvent.fromJson(json);
      default:
        throw FormatException('Unknown message type: $type', line);
    }
  }
}

/// Request from Flutter to Python backend.
class Request implements ProtocolMessage {
  @override
  final String type = 'request';
  final String id;
  final String method;
  final Map<String, dynamic> params;

  Request({
    required this.id,
    required this.method,
    required this.params,
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      id: json['id'] as String,
      method: json['method'] as String,
      params: (json['params'] as Map<String, dynamic>?) ?? {},
    );
  }

  factory Request.fromJsonString(String line) {
    return Request.fromJson(jsonDecode(line) as Map<String, dynamic>);
  }

  String toJson() {
    return jsonEncode({
      'type': type,
      'id': id,
      'method': method,
      'params': params,
    });
  }
}

/// Error details in a response.
class ProtocolError {
  final String code;
  final String message;

  ProtocolError({required this.code, required this.message});

  factory ProtocolError.fromJson(Map<String, dynamic> json) {
    return ProtocolError(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'code': code, 'message': message};
}

/// Response from Python backend to Flutter.
class Response implements ProtocolMessage {
  @override
  final String type = 'response';
  final String id;
  final dynamic result;
  final ProtocolError? error;

  Response._({
    required this.id,
    this.result,
    this.error,
  });

  factory Response.success({required String id, dynamic result}) {
    return Response._(id: id, result: result);
  }

  factory Response.error({required String id, required String code, required String message}) {
    return Response._(id: id, error: ProtocolError(code: code, message: message));
  }

  factory Response.fromJson(Map<String, dynamic> json) {
    final error = json['error'] != null
        ? ProtocolError.fromJson(json['error'] as Map<String, dynamic>)
        : null;
    return Response._(
      id: json['id'] as String,
      result: json['result'],
      error: error,
    );
  }

  factory Response.fromJsonString(String line) {
    return Response.fromJson(jsonDecode(line) as Map<String, dynamic>);
  }

  String toJson() {
    final map = <String, dynamic>{
      'type': type,
      'id': id,
    };
    if (result != null) {
      map['result'] = result;
    }
    if (error != null) {
      map['error'] = error!.toJson();
    }
    return jsonEncode(map);
  }
}

/// Real-time progress event during transfer.
class ProgressEvent implements ProtocolMessage {
  @override
  final String type = 'progress';
  final String transferId;
  final String phase;
  final String package;
  final String item;
  final int bytesTransferred;
  final int bytesTotal;
  final double percentage;
  final double transferRateBps;
  final int etaSeconds;

  ProgressEvent({
    required this.transferId,
    required this.phase,
    required this.package,
    required this.item,
    required this.bytesTransferred,
    required this.bytesTotal,
    required this.percentage,
    required this.transferRateBps,
    required this.etaSeconds,
  });

  factory ProgressEvent.fromJson(Map<String, dynamic> json) {
    return ProgressEvent(
      transferId: json['transferId'] as String? ?? '',
      phase: json['phase'] as String? ?? '',
      package: json['package'] as String? ?? '',
      item: json['item'] as String? ?? '',
      bytesTransferred: (json['bytesTransferred'] as num?)?.toInt() ?? 0,
      bytesTotal: (json['bytesTotal'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      transferRateBps: (json['transferRateBps'] as num?)?.toDouble() ?? 0.0,
      etaSeconds: (json['etaSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  factory ProgressEvent.fromJsonString(String line) {
    return ProgressEvent.fromJson(jsonDecode(line) as Map<String, dynamic>);
  }

  String toJson() {
    return jsonEncode({
      'type': type,
      'transferId': transferId,
      'phase': phase,
      'package': package,
      'item': item,
      'bytesTransferred': bytesTransferred,
      'bytesTotal': bytesTotal,
      'percentage': percentage,
      'transferRateBps': transferRateBps,
      'etaSeconds': etaSeconds,
    });
  }
}

/// Phase transition event (pull→push→complete).
class PhaseChangeEvent implements ProtocolMessage {
  @override
  final String type = 'phase_change';
  final String transferId;
  final String fromPhase;
  final String toPhase;

  PhaseChangeEvent({
    required this.transferId,
    required this.fromPhase,
    required this.toPhase,
  });

  factory PhaseChangeEvent.fromJson(Map<String, dynamic> json) {
    return PhaseChangeEvent(
      transferId: json['transferId'] as String? ?? '',
      fromPhase: json['from'] as String? ?? '',
      toPhase: json['to'] as String? ?? '',
    );
  }

  factory PhaseChangeEvent.fromJsonString(String line) {
    return PhaseChangeEvent.fromJson(jsonDecode(line) as Map<String, dynamic>);
  }

  String toJson() {
    return jsonEncode({
      'type': type,
      'transferId': transferId,
      'from': fromPhase,
      'to': toPhase,
    });
  }
}

/// Backend event (adb_info, driver_issue, etc.).
class BackendEvent implements ProtocolMessage {
  @override
  final String type = 'event';
  final String event;
  final Map<String, dynamic> data;

  BackendEvent({
    required this.event,
    required this.data,
  });

  factory BackendEvent.fromJson(Map<String, dynamic> json) {
    return BackendEvent(
      event: json['event'] as String? ?? '',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
    );
  }

  factory BackendEvent.fromJsonString(String line) {
    return BackendEvent.fromJson(jsonDecode(line) as Map<String, dynamic>);
  }

  String toJson() {
    return jsonEncode({
      'type': type,
      'event': event,
      'data': data,
    });
  }
}
