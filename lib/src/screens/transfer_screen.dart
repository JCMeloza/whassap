import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';

/// Step 3 of the wizard: real-time transfer progress.
///
/// Shows phase indicator (Pull → Push → Complete), progress bar,
/// percentage, transfer rate, ETA, current item, and pause/cancel controls.
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer'),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<TransferProvider>(
        builder: (context, provider, _) {
          // Completed → navigate to completion screen
          if (provider.isCompleted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/completion');
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Phase indicator
                _buildPhaseIndicator(provider, theme),
                const SizedBox(height: 32),

                // Progress content
                Expanded(child: _buildProgressContent(provider, theme)),

                // Control buttons
                _buildControls(provider, theme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhaseIndicator(TransferProvider provider, ThemeData theme) {
    final phase = provider.phase;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PhaseStep(
          label: 'Pull',
          active: phase == 'pull' || phase == 'push' || phase == 'complete',
          completed: phase == 'push' || phase == 'complete',
        ),
        Container(
          width: 60,
          height: 2,
          color: phase == 'pull' || phase == 'push' || phase == 'complete'
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        _PhaseStep(
          label: 'Push',
          active: phase == 'push' || phase == 'complete',
          completed: phase == 'complete',
        ),
        Container(
          width: 60,
          height: 2,
          color: phase == 'complete'
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        _PhaseStep(
          label: 'Complete',
          active: phase == 'complete',
          completed: phase == 'complete',
        ),
      ],
    );
  }

  Widget _buildProgressContent(TransferProvider provider, ThemeData theme) {
    // Idle state
    if (provider.isIdle) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing transfer...'),
          ],
        ),
      );
    }

    // Error state
    if (provider.isFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Transfer Failed',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                provider.resetTransfer();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Cancelled state
    if (provider.isCancelled) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cancel_outlined,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Transfer Cancelled',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                provider.resetTransfer();
                Navigator.pop(context);
              },
              child: const Text('Back to Start'),
            ),
          ],
        ),
      );
    }

    // Active transfer (transferring or paused)
    final percentage = provider.percentage;
    final isPaused = provider.isPaused;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Big percentage text
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isPaused
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 24),

        // Transfer details
        if (!isPaused) ...[
          _detailRow(
            Icons.speed,
            'Speed',
            provider.formattedRate,
            theme,
          ),
          const SizedBox(height: 8),
          _detailRow(
            Icons.timer,
            'ETA',
            provider.formattedEta,
            theme,
          ),
          const SizedBox(height: 8),
          _detailRow(
            Icons.description,
            'File',
            provider.currentItem ?? '--',
            theme,
          ),
        ] else
          Text(
            'Paused',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildControls(TransferProvider provider, ThemeData theme) {
    // No controls in idle, failed, or cancelled states
    if (provider.isIdle || provider.isFailed || provider.isCancelled) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (provider.isTransferring) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => provider.pauseTransfer(),
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmCancel(provider),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ] else if (provider.isPaused) ...[
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => provider.resumeTransfer(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmCancel(provider),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
        if (provider.isCompleted)
          FilledButton(
            onPressed: () => Navigator.pushReplacementNamed(
              context,
              '/completion',
            ),
            child: const Text('View Results'),
          ),
      ],
    );
  }

  void _confirmCancel(TransferProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Transfer?'),
        content: const Text(
          'Partial data is preserved on the destination.\n'
          'You can re-run the transfer to complete it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Going'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.cancelTransfer();
            },
            child: const Text('Cancel Transfer'),
          ),
        ],
      ),
    );
  }
}

/// A single step in the phase indicator row.
class _PhaseStep extends StatelessWidget {
  final String label;
  final bool active;
  final bool completed;

  const _PhaseStep({
    required this.label,
    required this.active,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = completed
        ? theme.colorScheme.primary
        : (active
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.outline.withValues(alpha: 0.3));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: completed
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : (active
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: active
                ? theme.colorScheme.onSurface
                : theme.colorScheme.outline,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
