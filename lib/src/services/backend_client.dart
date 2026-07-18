import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../protocol/protocol.dart';

/// Abstract transport for backend communication.
///
/// Allows mocking in tests without spawning a real subprocess.
abstract class BackendTransport {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  void addStdin(List<int> data);
  Future<void> close();
  Future<int> get exitCode;
}

/// A transport that spawns a real subprocess.
class ProcessTransport extends BackendTransport {
  final Process _process;

  ProcessTransport(this._process);

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  void addStdin(List<int> data) {
    _process.stdin.add(data);
  }

  @override
  Future<void> close() async {
    _process.stdin.close();
    try {
      await _process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      _process.kill();
      await _process.exitCode;
    }
  }

  @override
  Future<int> get exitCode => _process.exitCode;
}

/// NDJSON protocol client for communicating with the Python backend.
///
/// Manages the subprocess lifecycle, sends requests, correlates
/// responses by request ID, and streams events (progress, phase change).
class BackendClient {
  BackendTransport? _transport;
  StreamSubscription<String>? _stdoutSub;
  final _uuid = const Uuid();
  final _pendingRequests = <String, Completer<Response>>{};

  final _progressController = StreamController<ProgressEvent>.broadcast();
  final _phaseChangeController = StreamController<PhaseChangeEvent>.broadcast();
  final _backendEventController = StreamController<BackendEvent>.broadcast();

  /// Creates a client with an optional transport.
  ///
  /// If no transport is provided, call [spawnProcess] to start the backend.
  BackendClient({BackendTransport? transport}) {
    if (transport != null) {
      _transport = transport;
      _startReading(transport);
    }
  }

  /// Stream of progress events from the backend.
  Stream<ProgressEvent> get progressStream => _progressController.stream;

  /// Stream of phase change events from the backend.
  Stream<PhaseChangeEvent> get phaseChangeStream =>
      _phaseChangeController.stream;

  /// Stream of backend events (adb_info, driver_issue, etc.).
  Stream<BackendEvent> get backendEventStream =>
      _backendEventController.stream;

  /// Spawn the Python backend process.
  ///
  /// [backendPath] is the path to the Python executable or bundled backend binary.
  /// [args] are additional arguments passed to the process (e.g. `['-m', 'backend.main']`).
  Future<void> spawnProcess(String backendPath, {List<String> args = const []}) async {
    final process = await Process.start(
      backendPath,
      args,
      mode: ProcessStartMode.normal,
    );

    final transport = ProcessTransport(process);
    _transport = transport;
    _startReading(transport);
  }

  void _startReading(BackendTransport transport) {
    _stdoutSub = transport.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) return;
            _handleLine(trimmed);
          },
          onError: (error) {
            // Log or handle stream error
          },
        );
  }

  void _handleLine(String line) {
    ProtocolMessage message;
    try {
      message = ProtocolMessage.parse(line);
    } catch (_) {
      // Skip unparseable lines
      return;
    }

    switch (message) {
      case Response resp:
        _resolvePending(resp);
      case ProgressEvent event:
        _progressController.add(event);
      case PhaseChangeEvent event:
        _phaseChangeController.add(event);
      case BackendEvent event:
        _backendEventController.add(event);
      default:
        break;
    }
  }

  void _resolvePending(Response response) {
    final completer = _pendingRequests.remove(response.id);
    if (completer != null) {
      completer.complete(response);
    }
  }

  /// Send a typed Request and wait for the correlated Response.
  Future<Response> sendRequest(Request request) async {
    final completer = Completer<Response>();
    _pendingRequests[request.id] = completer;

    final line = '${request.toJson()}\n';
    _transport?.addStdin(utf8.encode(line));

    return completer.future;
  }

  /// Send a raw JSON request string and wait for the Response.
  Future<Response> sendRequestString(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    return sendRequest(Request.fromJson(data));
  }

  /// Generate a UUID and send a request with that ID.
  Future<Response> callMethod(
    String method,
    Map<String, dynamic> params,
  ) async {
    final id = _uuid.v4();
    return sendRequest(Request(id: id, method: method, params: params));
  }

  /// Dispose of the client, closing transport and controllers.
  Future<void> dispose() async {
    // Complete any pending requests with an error so futures don't hang forever
    for (final entry in _pendingRequests.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(
          Exception('BackendClient disposed before response'),
          StackTrace.current,
        );
      }
    }
    _pendingRequests.clear();

    await _stdoutSub?.cancel();
    await _transport?.close();
    await _progressController.close();
    await _phaseChangeController.close();
    await _backendEventController.close();
  }
}
