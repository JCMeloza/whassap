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
        title: const Text('¡Transferencia completada!'),
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
          '¡Transferencia completada!',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Tus datos de WhatsApp se transfirieron al dispositivo de destino.',
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
              'Resumen de transferencia',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _summaryRow(
              'Datos transferidos',
              TransferProvider.formatBytes(provider.bytesTransferred),
              theme,
            ),
            const SizedBox(height: 8),
            _summaryRow(
              'Tamaño total',
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
          'Guía de restauración',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Seguí estos pasos en tu dispositivo de destino para completar la restauración:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _restoreStep(1, 'En tu teléfono nuevo, abrí WhatsApp y verificá tu número de teléfono.'),
        _restoreStep(2, 'WhatsApp detectará la copia local cuando registres el mismo número.'),
        _restoreStep(3, "Tocá 'Restaurar' cuando aparezca. Esperá a que termine — no lo saltees."),
        _restoreStep(4, 'Abrí los chats para verificar que los mensajes y archivos multimedia estén correctos.'),
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
            content: Text('La verificación requiere una conexión activa con el backend.'),
            duration: Duration(seconds: 3),
          ),
        );
      },
      icon: const Icon(Icons.verified_user),
      label: const Text('Verificar en dispositivo'),
    );
  }

  Widget _buildTroubleshooting(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Solución de problemas',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _tipCard(
          Icons.info_outline,
          "Si 'Restaurar' no aparece:",
          'Asegurate de estar usando el mismo número de teléfono. '
              'WhatsApp solo restaura copias del número registrado.',
          theme,
        ),
        const SizedBox(height: 8),
        _tipCard(
          Icons.info_outline,
          'Si los archivos multimedia no aparecen:',
          'Esperá a que se descarguen en segundo plano. '
              'WhatsApp descarga el contenido multimedia de forma diferida después de restaurar.',
          theme,
        ),
        const SizedBox(height: 8),
        _tipCard(
          Icons.info_outline,
          "Si ves 'Copia de seguridad no encontrada':",
          'Verificá que los datos se hayan insertado en la ruta correcta '
              'para tu versión de Android.',
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
                'Podés ejecutar la transferencia de nuevo cuando quieras. '
                'WhatsApp combina las bases de datos y deduplica el contenido multimedia al restaurar.',
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
            child: const Text('Transferir de nuevo'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ),
      ],
    );
  }
}
