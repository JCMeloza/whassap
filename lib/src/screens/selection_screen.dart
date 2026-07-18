import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/scan_result.dart';
import '../providers/device_provider.dart';
import '../providers/scan_provider.dart';
import '../providers/transfer_provider.dart';

/// Step 2 of the wizard: data type and package selection.
///
/// Shows scan results from the source device, allows user to select
/// which packages (WhatsApp / WhatsApp Business) and data types
/// (Databases / Media) to transfer.
class SelectionScreen extends StatefulWidget {
  const SelectionScreen({super.key});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deviceProvider = context.read<DeviceProvider>();
      final scanProvider = context.read<ScanProvider>();
      if (deviceProvider.sourceDevice != null &&
          scanProvider.scanResult == null) {
        scanProvider.startScan(deviceProvider.sourceDevice!.serial);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Data'),
      ),
      body: Consumer2<ScanProvider, DeviceProvider>(
        builder: (context, scanProvider, deviceProvider, _) {
          return Column(
            children: [
              // Source/dest info
              _buildDeviceInfo(deviceProvider, theme),
              // Main content
              Expanded(child: _buildContent(scanProvider, deviceProvider, theme)),
              // Bottom bar
              _buildBottomBar(scanProvider, deviceProvider, theme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeviceInfo(DeviceProvider deviceProvider, ThemeData theme) {
    final source = deviceProvider.sourceDevice;
    final dest = deviceProvider.destDevice;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Text(
        '${source?.model ?? "—"} (source)  →  ${dest?.model ?? "—"} (dest)',
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildContent(
    ScanProvider scanProvider,
    DeviceProvider deviceProvider,
    ThemeData theme,
  ) {
    // Scanning state
    if (scanProvider.isScanning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning device for WhatsApp data...'),
          ],
        ),
      );
    }

    // Error state
    if (scanProvider.errorMessage != null && scanProvider.scanResult == null) {
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
                scanProvider.errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => scanProvider.startScan(
                  deviceProvider.sourceDevice!.serial,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // No scan result yet
    final result = scanProvider.scanResult;
    if (result == null) {
      return const Center(child: Text('No scan data available.'));
    }

    // Empty state
    if (result.packages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text('No WhatsApp data found on this device.'),
            ],
          ),
        ),
      );
    }

    // Package list with data types
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...result.packages.map((pkg) => _buildPackageSection(
              pkg,
              scanProvider,
              theme,
            )),
        const SizedBox(height: 16),
        _buildSizeSummary(result, scanProvider, theme),
      ],
    );
  }

  Widget _buildPackageSection(
    PackageData pkg,
    ScanProvider scanProvider,
    ThemeData theme,
  ) {
    final databasesSize = pkg.databases.fold<int>(0, (s, db) => s + db.sizeBytes);
    final mediaSize = pkg.media.fold<int>(0, (s, m) => s + m.sizeBytes);
    final dbCount = pkg.databases.length;
    final mediaCount = pkg.media.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Package name header
            Text(
              pkg.package == 'com.whatsapp'
                  ? 'WhatsApp (com.whatsapp)'
                  : 'WhatsApp Business (com.whatsapp.w4b)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Databases checkbox
            if (pkg.databases.isNotEmpty)
              CheckboxListTile(
                title: Text('Databases ($dbCount files — ${_formatBytes(databasesSize)})'),
                value: scanProvider.includeDatabases && scanProvider.isPackageSelected(pkg.package),
                onChanged: (_) {
                  if (!scanProvider.isPackageSelected(pkg.package)) {
                    scanProvider.togglePackage(pkg.package);
                  }
                  scanProvider.toggleDatabases();
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),

            // Media checkbox
            if (pkg.media.isNotEmpty)
              CheckboxListTile(
                title: Text('Media ($mediaCount categories — ${_formatBytes(mediaSize)})'),
                value: scanProvider.includeMedia && scanProvider.isPackageSelected(pkg.package),
                onChanged: (_) {
                  if (!scanProvider.isPackageSelected(pkg.package)) {
                    scanProvider.togglePackage(pkg.package);
                  }
                  scanProvider.toggleMedia();
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),

            // Package total
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Package total: ${_formatBytes(scanProvider.packageBytes(pkg))}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSummary(
    ScanResult result,
    ScanProvider scanProvider,
    ThemeData theme,
  ) {
    final selectedBytes = scanProvider.totalBytes;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total selected',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              _formatBytes(selectedBytes),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    ScanProvider scanProvider,
    DeviceProvider deviceProvider,
    ThemeData theme,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (scanProvider.totalBytes > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_formatBytes(scanProvider.totalBytes)} to transfer',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            FilledButton(
              onPressed: scanProvider.canTransfer
                  ? () => _startTransfer(scanProvider, deviceProvider)
                  : null,
              child: const Text('Start Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  void _startTransfer(ScanProvider scanProvider, DeviceProvider deviceProvider) {
    // Build items list based on selection
    final items = <String>[];
    for (final pkg in scanProvider.scanResult!.packages) {
      if (!scanProvider.isPackageSelected(pkg.package)) continue;
      if (scanProvider.includeDatabases) {
        for (final db in pkg.databases) {
          items.add(db.path);
        }
      }
      if (scanProvider.includeMedia) {
        for (final media in pkg.media) {
          items.add(media.path);
        }
      }
    }

    // Start the transfer
    context.read<TransferProvider>().startTransfer(
      sourceSerial: deviceProvider.sourceDevice!.serial,
      destSerial: deviceProvider.destDevice!.serial,
      packages: scanProvider.selectedPackages,
      items: items,
    );

    // Navigate to transfer screen
    Navigator.pushNamed(context, '/transfer');
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }
}
