import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Versión Web: el SDK de Google Identity Services exige que el
/// inicio de sesión se haga mediante un botón renderizado por el
/// propio SDK (no se puede disparar `authenticate()` manualmente en
/// Web). El resultado del login llega igualmente a través del stream
/// `GoogleAuthService`/`authenticationEvents`, escuchado en
/// `GoogleAuthService`.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: web.renderButton(),
    );
  }
}
