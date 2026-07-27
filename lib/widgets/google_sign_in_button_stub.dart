import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

/// Versión nativa (Android/iOS): botón normal de Material, ya que
/// fuera de Web sí se puede disparar `authenticate()` de forma
/// imperativa.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return SizedBox(
      height: 44,
      width: 240,
      child: ElevatedButton.icon(
        onPressed: () => auth.signInWithGoogleNative(),
        icon: const Icon(Icons.login_rounded),
        label: const Text('Iniciar sesión con Google'),
      ),
    );
  }
}
