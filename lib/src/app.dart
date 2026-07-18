import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/selection_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/completion_screen.dart';

/// Root MaterialApp for the WhatsApp Transfer wizard.
///
/// Routes:
/// - `/` → [WelcomeScreen] — instructions and procedure guide
/// - `/home` → [HomeScreen] — device detection and source/dest selection
/// - `/selection` → [SelectionScreen] — data type selection
/// - `/transfer` → [TransferScreen] — transfer progress
/// - `/completion` → [CompletionScreen] — restore guidance
class WhatsAppTransferApp extends StatelessWidget {
  const WhatsAppTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Transfer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const WelcomeScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/selection':
            return MaterialPageRoute(builder: (_) => const SelectionScreen());
          case '/transfer':
            return MaterialPageRoute(builder: (_) => const TransferScreen());
          case '/completion':
            return MaterialPageRoute(builder: (_) => const CompletionScreen());
          default:
            return MaterialPageRoute(builder: (_) => const WelcomeScreen());
        }
      },
    );
  }
}
