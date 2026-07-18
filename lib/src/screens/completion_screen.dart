import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';

/// Step 4 of the wizard: completion summary and restore guidance.
///
/// Shows transfer summary (bytes, items, duration), step-by-step restore
/// instructions, "Verify on Device" button, troubleshooting tips, and
/// "Transfer Again" button.
class CompletionScreen extends StatelessWidget {
  const CompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Complete!'),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<TransferProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Success header
              _buildHeader(provider, theme),
              const SizedBox(height: 24),

              // Summary card
              _buildSummaryCard(provider, theme),
              const SizedBox(height: 24),

              // Restore guidance
              _buildRestoreGuidance(theme),
              const SizedBox(height: 16),

              // Verify on Device
              _buildVerifyButton(context, theme),
              const SizedBox(height: 24),

              // Troubleshooting
              _buildTroubleshooting(theme),
              const SizedBox(height: 24),

              // Re-run guidance
              _buildRerunGuidance(theme),
              const SizedBox(height: 24),

              // Action buttons
              _buildActions(context, provider, theme),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(TransferProvider provider, ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.check_circle,
          size: 72,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Transfer Complete!',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Your WhatsApp data has been transferred to the destination device.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(TransferProvider provider, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transfer Summary',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _summaryRow(
              'Data transferred',
              TransferProvider.formatBytes(provider.bytesTransferred),
              theme,
            ),
            const SizedBox(height: 8),
            _summaryRow(
              'Total size',
              TransferProvider.formatBytes(provider.bytesTotal),
              theme,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRestoreGuidance(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Restore Guidance',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Follow these steps on your destination device to complete the restore:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _restoreStep(1, 'On your new phone, open WhatsApp and verify your phone number.'),
        _restoreStep(2, "WhatsApp will detect the local backup when you register the same number."),
        _restoreStep(3, "Tap 'Restore' when prompted. Wait for restore to complete — do not skip."),
        _restoreStep(4, 'Open chats to verify messages and media appear correctly.'),
      ],
    );
  }

  Widget _restoreStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton(BuildContext context, ThemeData theme) {
    return OutlinedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification requires an active backend connection.'),
            duration: Duration(seconds: 3),
          ),
        );
      },
      icon: const Icon(Icons.verified_user),
      label: const Text('Verify on Device'),
    );
  }

  Widget _buildTroubleshooting(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Troubleshooting',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _tipCard(
          Icons.info_outline,
          "If 'Restore' doesn't appear:",
          'Ensure you are using the same phone number. '
              'WhatsApp only restores backups for the registered number.',
          theme,
        ),
        const SizedBox(height: 8),
        _tipCard(
          Icons.info_outline,
          'If media does not appear:',
          'Wait for media to download in the background. '
              'WhatsApp downloads media lazily after restore.',
          theme,
        ),
        const SizedBox(height: 8),
        _tipCard(
          Icons.info_outline,
          "If you see 'Backup not found':",
          'Verify the data was pushed to the correct path '
              'for your Android version.',
          theme,
        ),
      ],
    );
  }

  Widget _tipCard(
    IconData icon,
    String title,
    String body,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRerunGuidance(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.replay,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You can run the transfer again anytime. '
                'WhatsApp merges databases and deduplicates media on restore.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    TransferProvider provider,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              provider.resetTransfer();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
            child: const Text('Transfer Again'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}
