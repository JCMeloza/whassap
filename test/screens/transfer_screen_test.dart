import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_transfer/src/models/transfer.dart';
import 'package:whatsapp_transfer/src/providers/transfer_provider.dart';
import 'package:whatsapp_transfer/src/screens/completion_screen.dart';
import 'package:whatsapp_transfer/src/screens/transfer_screen.dart';
import 'package:whatsapp_transfer/src/services/backend_client.dart';
import 'package:whatsapp_transfer/src/services/transfer_service.dart';

/// Minimal mock transport for TransferService.
class _MockTransferTransport extends BackendTransport {
  final _ctrl = StreamController<List<int>>();

  @override
  Stream<List<int>> get stdout => _ctrl.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  void addStdin(List<int> data) {
    final line = utf8.decode(data).trim();
    final req = jsonDecode(line) as Map<String, dynamic>;
    final id = req['id'] as String;
    final method = req['method'] as String;

    Map<String, dynamic> response;
    switch (method) {
      case 'transfer.start':
        response = {'type': 'response', 'id': id, 'result': {'transferId': 't1'}};
        break;
      case 'transfer.pause':
      case 'transfer.resume':
      case 'transfer.cancel':
      default:
        response = {'type': 'response', 'id': id, 'result': {}};
    }
    _ctrl.add(utf8.encode('${jsonEncode(response)}\n'));
  }

  @override
  Future<void> close() async => _ctrl.close();
  @override
  Future<int> get exitCode => Future.value(0);
}

/// Wrapper with routes for tests that need navigation.
Widget _wrapWithRoutes(TransferProvider provider) {
  return MaterialApp(
    home: ChangeNotifierProvider<TransferProvider>.value(
      value: provider,
      child: const TransferScreen(),
    ),
    routes: {
      '/completion': (_) => ChangeNotifierProvider<TransferProvider>.value(
            value: provider,
            child: const CompletionScreen(),
          ),
    },
  );
}

void main() {
  group('TransferScreen', () {
    testWidgets('shows idle state initially', (tester) async {
      final transport = _MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);
      final provider = TransferProvider(service);

      addTearDown(() {
        provider.dispose();
        client.dispose();
      });

      await tester.pumpWidget(_wrapWithRoutes(provider));
      await tester.pump();

      expect(find.text('Transferencia'), findsOneWidget);
    });

    testWidgets('shows progress bar and percentage during transfer',
        (tester) async {
      final transport = _MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);
      final provider = TransferProvider(service);

      addTearDown(() {
        provider.dispose();
        client.dispose();
      });

      provider.updateState(
        const TransferState(
          status: TransferStatus.transferring,
          transferId: 't1',
          phase: 'pull',
          currentItem: 'Databases/msgstore.db.crypt14',
          bytesTransferred: 2500000000,
          bytesTotal: 5000000000,
          transferRateBps: 12000000,
          etaSeconds: 200,
        ),
      );

      await tester.pumpWidget(_wrapWithRoutes(provider));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.textContaining('msgstore.db.crypt14'),
        findsOneWidget,
      );
    });

    testWidgets('shows pause and cancel buttons during transfer',
        (tester) async {
      final transport = _MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);
      final provider = TransferProvider(service);

      addTearDown(() {
        provider.dispose();
        client.dispose();
      });

      provider.updateState(
        const TransferState(
          status: TransferStatus.transferring,
          transferId: 't1',
          phase: 'pull',
          bytesTransferred: 0,
          bytesTotal: 1000,
        ),
      );

      await tester.pumpWidget(_wrapWithRoutes(provider));
      await tester.pump();

      expect(find.text('Pausar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('shows resume button when paused', (tester) async {
      final transport = _MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);
      final provider = TransferProvider(service);

      addTearDown(() {
        provider.dispose();
        client.dispose();
      });

      provider.updateState(
        const TransferState(
          status: TransferStatus.paused,
          transferId: 't1',
          phase: 'pull',
          bytesTransferred: 100,
          bytesTotal: 1000,
        ),
      );

      await tester.pumpWidget(_wrapWithRoutes(provider));
      await tester.pump();

      expect(find.text('Reanudar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('shows error state on failure', (tester) async {
      final transport = _MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);
      final provider = TransferProvider(service);

      addTearDown(() {
        provider.dispose();
        client.dispose();
      });

      provider.updateState(
        const TransferState(
          status: TransferStatus.failed,
          transferId: 't1',
          errorMessage: 'ADB connection lost',
          bytesTransferred: 100,
          bytesTotal: 1000,
        ),
      );

      await tester.pumpWidget(_wrapWithRoutes(provider));
      await tester.pump();

      expect(find.textContaining('ADB connection lost'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('shows completed state', (tester) async {
      final transport = _MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);
      final provider = TransferProvider(service);

      addTearDown(() {
        provider.dispose();
        client.dispose();
      });

      await tester.pumpWidget(_wrapWithRoutes(provider));
      await tester.pump();

      provider.updateState(
        const TransferState(
          status: TransferStatus.completed,
          transferId: 't1',
          phase: 'complete',
          bytesTransferred: 1000,
          bytesTotal: 1000,
        ),
      );

      // Pump to trigger postFrameCallback that does pushReplacementNamed
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // After navigation, should see the CompletionScreen
      expect(find.text('Guía de restauración'), findsOneWidget);
    });

    testWidgets('shows cancelled state', (tester) async {
      final transport = _MockTransferTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);
      final provider = TransferProvider(service);

      addTearDown(() {
        provider.dispose();
        client.dispose();
      });

      provider.updateState(
        const TransferState(
          status: TransferStatus.cancelled,
          transferId: 't1',
          bytesTransferred: 500,
          bytesTotal: 1000,
        ),
      );

      await tester.pumpWidget(_wrapWithRoutes(provider));
      await tester.pump();

      expect(find.text('Transferencia cancelada'), findsOneWidget);
      expect(find.text('Volver al inicio'), findsOneWidget);
    });
  });
}
