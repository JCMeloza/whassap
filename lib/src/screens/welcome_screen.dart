import 'package:flutter/material.dart';

/// Initial screen shown when the app opens.
///
/// Explains the overall procedure step by step so the user knows
/// exactly what to do before starting.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const SizedBox(height: 24),

            // App icon / logo area
            Icon(
              Icons.wifi_tethering,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'WhatsApp Transfer',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Transferí tus chats de WhatsApp\nde un Android a otro',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Section: qué necesitás
            _sectionHeader('Qué necesitás', Icons.checklist, theme),
            const SizedBox(height: 8),
            _bulletPoint('Dos dispositivos Android con WhatsApp instalado', theme),
            _bulletPoint('Cable USB para conectar al menos un dispositivo', theme),
            _bulletPoint('Depuración USB activada en ambos dispositivos', theme),

            const SizedBox(height: 24),

            // Section: pasos
            _sectionHeader('Pasos a seguir', Icons.format_list_numbered, theme),
            const SizedBox(height: 8),
            _stepCard(
              step: 1,
              title: 'Conectá los dispositivos',
              desc: 'Conectá ambos teléfonos Android por USB a la PC. '
                  'Confirmá el permiso de depuración USB en cada uno.',
              theme: theme,
            ),
            const SizedBox(height: 8),
            _stepCard(
              step: 2,
              title: 'Seleccioná origen y destino',
              desc: 'Elegí cuál es el teléfono de origen (el que tiene '
                  'los datos) y cuál es el destino (el nuevo).',
              theme: theme,
            ),
            const SizedBox(height: 8),
            _stepCard(
              step: 3,
              title: 'Elegí qué datos transferir',
              desc: 'Seleccioná WhatsApp, WhatsApp Business, bases de datos '
                  'y/o archivos multimedia según lo que quieras pasar.',
              theme: theme,
            ),
            const SizedBox(height: 8),
            _stepCard(
              step: 4,
              title: 'Esperá la transferencia',
              desc: 'La app extrae los datos del origen y los inserta '
                  'en el destino. Puede llevar varios minutos.',
              theme: theme,
            ),
            const SizedBox(height: 8),
            _stepCard(
              step: 5,
              title: 'Restaurá en el teléfono nuevo',
              desc: 'Abrí WhatsApp en el destino con el mismo número. '
                  'Tocá "Restaurar" cuando aparezca la opción.',
              theme: theme,
            ),

            const SizedBox(height: 32),

            // Tip
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tip: si la app no detecta tu dispositivo, '
                        'verificá que la depuración USB esté activada y '
                        'que hayas aceptado el permiso en el teléfono.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Start button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/home'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Comenzar'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _bulletPoint(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: theme.colorScheme.primary)),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCard({
    required int step,
    required String title,
    required String desc,
    required ThemeData theme,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
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
                  const SizedBox(height: 2),
                  Text(
                    desc,
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
}
