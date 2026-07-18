import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../providers/device_provider.dart';

/// Step 1 of the wizard: device detection and source/destination selection.
///
/// Shows detected Android devices, allows user to select source and
/// destination, and navigate to data selection.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().startPolling();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Transfer'),
        centerTitle: true,
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Expanded(child: _buildBody(provider, theme)),
              _buildBottomBar(provider, theme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(DeviceProvider provider, ThemeData theme) {
    // Loading state
    if (provider.isLoading && provider.devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for devices...'),
          ],
        ),
      );
    }

    // Error state
    if (provider.errorMessage != null && provider.devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: provider.refreshDevices,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (provider.devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_android,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No devices found',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Connect an Android device via USB\nwith USB debugging enabled.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: provider.refreshDevices,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    // Device list
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.devices.length,
      itemBuilder: (context, index) {
        final device = provider.devices[index];
        return _DeviceCard(
          device: device,
          isSource: provider.isSource(device),
          isDest: provider.isDest(device),
          onSelectSource: () => provider.selectDevice(device, asSource: true),
          onSelectDest: () => provider.selectDevice(device, asSource: false),
        );
      },
    );
  }

  Widget _buildBottomBar(DeviceProvider provider, ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.sourceDevice != null || provider.destDevice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Source: ${provider.sourceDevice?.model ?? "—"}  →  '
                  'Dest: ${provider.destDevice?.model ?? "—"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            FilledButton(
              onPressed: provider.canContinue
                  ? () => Navigator.pushNamed(context, '/selection')
                  : null,
              child: const Text('Continue to Data Selection'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for a single detected device.
class _DeviceCard extends StatelessWidget {
  final Device device;
  final bool isSource;
  final bool isDest;
  final VoidCallback onSelectSource;
  final VoidCallback onSelectDest;

  const _DeviceCard({
    required this.device,
    required this.isSource,
    required this.isDest,
    required this.onSelectSource,
    required this.onSelectDest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor =
        isSource ? Colors.green : (isDest ? Colors.blue : null);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: borderColor != null
          ? RoundedRectangleBorder(
              side: BorderSide(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_android),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    device.model,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (isSource)
                  Chip(
                    label: const Text('Source'),
                    backgroundColor: Colors.green.shade100,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (isDest)
                  Chip(
                    label: const Text('Dest'),
                    backgroundColor: Colors.blue.shade100,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              device.serial,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('API ${device.apiLevel}'),
                const SizedBox(width: 8),
                Chip(
                  label: Text(device.classification),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: device.packages.map((p) {
                final label = p == 'com.whatsapp'
                    ? 'WhatsApp'
                    : 'WhatsApp Business';
                return Chip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isSource)
                  TextButton(
                    onPressed: onSelectSource,
                    child: const Text('Select as Source'),
                  ),
                const SizedBox(width: 8),
                if (!isDest)
                  TextButton(
                    onPressed: onSelectDest,
                    child: const Text('Select as Dest'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
