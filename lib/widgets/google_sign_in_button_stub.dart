import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Versión para Android/otras plataformas nativas: un botón normal
/// que llama a `GoogleAuthService.signIn()` (usa `authenticate()`
/// nativo, que sí está soportado fuera de Web).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final auth = state.googleAuth;
    return ElevatedButton.icon(
      onPressed: () async {
        final user = await auth.signIn();
        if (user == null && auth.lastError != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo conectar: ${auth.lastError}')),
          );
        } else if (user != null) {
          await state.syncAfterGoogleConnected();
        }
      },
      icon: const Icon(Icons.login),
      label: const Text('Conectar con Google'),
    );
  }
}
