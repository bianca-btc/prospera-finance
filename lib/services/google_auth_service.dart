import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/google_config.dart';

/// Alcances (scopes) de Google necesarios para leer/escribir la hoja
/// de backup en Google Sheets y para poder crearla/encontrarla en el
/// Google Drive del propio usuario (solo archivos creados por esta
/// app, gracias a `drive.file`, nunca el resto del Drive).
const List<String> googleSheetsScopes = [
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive.file',
];

/// Envuelve `google_sign_in` v7 (API moderna basada en
/// `initialize()` + `attemptLightweightAuthentication()` +
/// `authenticate()` + `authorizationClient`) para exponer una
/// interfaz simple de sign-in/sign-out/autorización usada por
/// [GoogleSheetsService] y por la UI de Ajustes.
///
/// Es un [ChangeNotifier] para que la UI (botón "Conectar con
/// Google", estado de sincronización, etc.) se actualice sola.
class GoogleAuthService extends ChangeNotifier {
  GoogleSignInAccount? _currentUser;
  bool _initialized = false;
  bool _initializing = false;
  String? _lastError;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isConfigured => googleOAuthClientId.trim().isNotEmpty;
  bool get isInitialized => _initialized;
  String? get lastError => _lastError;

  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;

  /// Debe llamarse una única vez, idealmente al iniciar la app, antes
  /// de cualquier otra operación de sign-in. Es seguro llamarlo
  /// aunque [isConfigured] sea falso (simplemente no hace nada, para
  /// que el resto de la app siga funcionando 100% local).
  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    if (!isConfigured) {
      // Sin Client ID configurado: no se puede inicializar el SDK de
      // Google. La app sigue funcionando normalmente en modo local.
      return;
    }
    _initializing = true;
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(
        clientId: kIsWeb ? googleOAuthClientId : null,
        serverClientId: kIsWeb ? null : googleOAuthClientId,
      );
      _sub = signIn.authenticationEvents.listen(
        _handleAuthEvent,
        onError: (Object e, StackTrace st) {
          _lastError = e.toString();
          notifyListeners();
        },
      );
      _initialized = true;
      // Nota: la restauración silenciosa de sesión
      // (`attemptSilentSignIn`) se dispara explícitamente desde
      // `AppState.init()`, para poder esperar su resultado antes de
      // decidir si hay que restaurar datos desde Google Sheets o
      // cargar los datos semilla locales.
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('GoogleAuthService.initialize error: $e');
      }
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  void _handleAuthEvent(GoogleSignInAuthenticationEvent event) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      _currentUser = event.user;
      _lastError = null;
    } else if (event is GoogleSignInAuthenticationEventSignOut) {
      _currentUser = null;
    }
    notifyListeners();
  }

  /// Intenta reconectar la sesión sin interacción del usuario (ideal
  /// para llamar al arrancar la app, antes de decidir si hay que
  /// restaurar datos desde Google Sheets).
  Future<GoogleSignInAccount?> attemptSilentSignIn() async {
    if (!isConfigured || !_initialized) return null;
    try {
      final user = await GoogleSignIn.instance
          .attemptLightweightAuthentication();
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
      return user;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  /// Inicia sesión de forma interactiva (botón pulsado por el
  /// usuario). En Web, si la plataforma no soporta `authenticate()`
  /// directo, se debe usar el botón nativo de Google
  /// (`GoogleSignInButtonWeb`, ver widget correspondiente); en ese
  /// caso este método simplemente no hará nada y devolverá null.
  Future<GoogleSignInAccount?> signIn() async {
    if (!isConfigured) {
      _lastError =
          'Falta configurar el Client ID de Google (ver lib/config/google_config.dart).';
      notifyListeners();
      return null;
    }
    if (!_initialized) {
      await initialize();
    }
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      // En Web hay que usar el botón renderizado por Google (ver
      // GoogleSignInButtonWeb). No hacemos nada aquí.
      return null;
    }
    try {
      final user = await GoogleSignIn.instance.authenticate();
      _currentUser = user;
      _lastError = null;
      notifyListeners();
      return user;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // ignore
    }
    _currentUser = null;
    notifyListeners();
  }

  /// Devuelve encabezados HTTP `Authorization`/`X-Goog-AuthUser`
  /// listos para usar en llamadas REST a Sheets/Drive. Si
  /// [promptIfNecessary] es true y el usuario aún no autorizó los
  /// scopes, puede mostrar UI de consentimiento (solo debe llamarse
  /// así desde una interacción explícita del usuario).
  Future<Map<String, String>?> authHeaders({
    bool promptIfNecessary = false,
  }) async {
    final user = _currentUser;
    if (user == null) return null;
    try {
      return await user.authorizationClient.authorizationHeaders(
        googleSheetsScopes,
        promptIfNecessary: promptIfNecessary,
      );
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
