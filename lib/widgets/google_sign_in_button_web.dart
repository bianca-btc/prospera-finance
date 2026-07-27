import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:google_identity_services_web/id.dart' as gis_id;
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

import '../services/auth_service.dart';

/// Versión Web: el SDK de Google Identity Services exige que el
/// inicio de sesión se haga mediante un botón renderizado por el
/// propio SDK (no se puede disparar `authenticate()` manualmente en
/// Web). El resultado del login llega vía `onAuthStateChange` de
/// Supabase, ya escuchado internamente por [AuthService].
///
/// IMPORTANTE — por qué esta implementación NO usa
/// `google_sign_in_web`'s `renderButton()`: ese helper delega en
/// `FlexHtmlElementView`, que falla con un `TypeError` de
/// JS-interop cuando Google inyecta primero un nodo que no es un
/// `Element` (bug conocido de `google_sign_in_web` 1.1.3, ver
/// flutter/flutter#149236). La solución es llamar directamente a
/// `google.accounts.id.renderButton(...)` (vía
/// `google_identity_services_web`) sobre un `<div>` que registramos
/// nosotros mismos como platform view.
const String _gsiButtonViewType = 'prospera_gsi_button';
bool _gsiButtonViewFactoryRegistered = false;

void _ensureViewFactoryRegistered() {
  if (_gsiButtonViewFactoryRegistered) return;
  _gsiButtonViewFactoryRegistered = true;
  ui_web.platformViewRegistry.registerViewFactory(_gsiButtonViewType, (
    int viewId,
  ) {
    final web.HTMLDivElement element =
        web.document.createElement('div') as web.HTMLDivElement;
    element.id = 'prospera-gsi-btn-$viewId';
    element.style.width = '100%';
    element.style.height = '100%';
    element.style.display = 'flex';
    element.style.alignItems = 'center';
    element.style.justifyContent = 'center';
    element.style.overflow = 'hidden';
    return element;
  });
}

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _rendered = false;

  @override
  void initState() {
    super.initState();
    _ensureViewFactoryRegistered();
    context.read<AuthService>().prepareGoogleSignIn();
  }

  void _renderIntoElement(web.Element element) {
    if (_rendered) return;
    try {
      gis_id.id.renderButton(
        element,
        gis_id.GsiButtonConfiguration(
          type: gis_id.ButtonType.standard,
          theme: gis_id.ButtonTheme.filled_blue,
          size: gis_id.ButtonSize.large,
          text: gis_id.ButtonText.signin_with,
          shape: gis_id.ButtonShape.rectangular,
          logo_alignment: gis_id.ButtonLogoAlignment.left,
          width: 240,
        ),
      );
      _rendered = true;
    } catch (e) {
      // Si falla, se reintentará en el próximo build (p. ej. cuando
      // `googleReady` cambie de false a true).
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.googleReady) {
      return const SizedBox(
        height: 44,
        width: 240,
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      width: 240,
      child: HtmlElementView(
        viewType: _gsiButtonViewType,
        onPlatformViewCreated: (int viewId) {
          final element =
              ui_web.platformViewRegistry.getViewById(viewId) as web.Element;
          _renderIntoElement(element);
        },
      ),
    );
  }
}
