import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_transfer/src/models/transfer.dart';
import 'package:whatsapp_transfer/src/providers/transfer_provider.dart';
import 'package:whatsapp_transfer/src/screens/completion_screen.dart';
import 'package:whatsapp_transfer/src/services/backend_client.dart';
import 'package:whatsapp_transfer/src/services/transfer_service.dart';

/// Minimal mock transport.
class _MockTransport extends BackendTransport {
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
    _ctrl.add(utf8.encode(
      '{"type":"response","id":"$id","result":{}}\n',
    ));
  }

  @override
  Future<void> close() async => _ctrl.close();
  @override
  Future<int> get exitCode => Future.value(0);
}

Widget _wrapCompletionScreen(TransferProvider provider) {
  return MaterialApp(
    home: ChangeNotifierProvider<TransferProvider>.value(
      value: provider,
      child: const CompletionScreen(),
    ),
  );
}

void main() {
  group('CompletionScreen', () {
    testWidgets('shows completion summary', (tester) async {
      final transport = _MockTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);
      final provider = TransferProvider(service);

      addTearDown(() {
        provider.dispose();
        client.dispose();
      });

      provider.updateState(
        const TransferState(
          status: TransferStatus.completed,
          transferId: 't1',
          phase: 'complete',
          bytesTransferred: 5000000000,
          bytesTotal: 5000000000,
        ),
      );

      await tester.pumpWidget(_wrapCompletionScreen(provider));
      await tester.pump();

      // AppBar title has "Transfer Complete!" — just check it's there
      expect(
        find.text('Transfer Complete!'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('shows restore guidance section', (tester) async {
      final transport = _MockTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);
      final provider = TransferProvider(service);

      addTearDown(() {
        provider.dispose();
        client.dispose();
      });

      provider.updateState(
        const TransferState(
          status: TransferStatus.completed,
          transferId: 't1',
          phase: 'complete',
          bytesTransferred: 5000000000,
          bytesTotal: 5000000000,
        ),
      );

      await tester.pumpWidget(_wrapCompletionScreen(provider));
      await tester.pump();

      // Restore guidance section header (above fold)
      expect(find.text('Restore Guidance'), findsOneWidget);

      // Scroll down to find "Verify on Device"
      await tester.scrollUntilVisible(
        find.text('Verify on Device'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Verify on Device'), findsOneWidget);
    });

    testWidgets('shows troubleshooting and Transfer Again', (tester) async {
      final transport = _MockTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);
      final provider = TransferProvider(service);

      addTearDown(() {
        provider.dispose();
        client.dispose();
      });

      provider.updateState(
        const TransferState(
          status: TransferStatus.completed,
          transferId: 't1',
          phase: 'complete',
          bytesTransferred: 1000,
          bytesTotal: 1000,
        ),
      );

      await tester.pumpWidget(_wrapCompletionScreen(provider));
      await tester.pump();

      // Scroll to find "Troubleshooting"
      await tester.scrollUntilVisible(
        find.text('Troubleshooting'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Troubleshooting'), findsOneWidget);

      // Scroll further to find "Transfer Again"
      await tester.scrollUntilVisible(
        find.text('Transfer Again'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Transfer Again'), findsOneWidget);
    });

    testWidgets('shows step-by-step restore instructions', (tester) async {
      final transport = _MockTransport();
      final client = BackendClient(transport: transport);
      final service = TransferService(client);
      final provider = TransferProvider(service);

      addTearDown(() {
        provider.dispose();
        client.dispose();
      });

      provider.updateState(
        const TransferState(
          status: TransferStatus.completed,
          transferId: 't1',
          phase: 'complete',
          bytesTransferred: 1000,
          bytesTotal: 1000,
        ),
      );

      await tester.pumpWidget(_wrapCompletionScreen(provider));
      await tester.pump();

      // Key restore step text (above fold in the restore guidance section)
      expect(
        find.textContaining('verify your phone number'),
        findsOneWidget,
      );
      expect(
        find.textContaining("Tap 'Restore'"),
        findsOneWidget,
      );
    });
  });
}
