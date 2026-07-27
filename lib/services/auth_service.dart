import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'supabase_config.dart';

/// Usuario autenticado (mínimo necesario para el resto del app).
class AppUser {
  final String id; // user_id de Supabase Auth = auth.uid()
  final String email;
  final String? displayName;
  final String? photoUrl;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });
}

/// Servicio único de autenticación: Google Sign-In → sesión de
/// Supabase Auth (`signInWithIdToken`). Reemplaza por completo la
/// sincronización anterior con Google Sheets — ahora los datos viven
/// directamente en Postgres (Supabase), filtrados por RLS
/// (`user_id = auth.uid()`).
///
/// Diseño intencionalmente simple (un solo `ChangeNotifier`, sin capas
/// de Repository/DataSource): la app es de un solo usuario por cuenta,
/// sin necesidad de abstraer el backend de auth.
class AuthService extends ChangeNotifier {
  bool _googleInitialized = false;
  bool googleReady = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEventsSub;
  StreamSubscription<sb.AuthState>? _supabaseAuthSub;

  /// Nonce crudo (sin hashear), reutilizado en el canje idToken →
  /// sesión Supabase (ver comentario largo en [_ensureGoogleInitialized]).
  String? _rawNonce;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  String? lastError;

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  /// Debe llamarse una sola vez al iniciar la app (antes de `runApp`),
  /// después de `Supabase.initialize`. Restaura la sesión persistida
  /// (si existe) y escucha cambios futuros de sesión.
  Future<void> init() async {
    final session = _client.auth.currentSession;
    if (session != null) {
      _currentUser = _mapUser(session.user);
    }
    _supabaseAuthSub = _client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      _currentUser = user == null ? null : _mapUser(user);
      notifyListeners();
    });
  }

  /// Inicializa el SDK de Google (idempotente). En Web debe llamarse
  /// ANTES de renderizar el botón oficial (ver [GoogleSignInButton]),
  /// ya que ese botón necesita el SDK ya inicializado para pintarse.
  Future<void> prepareGoogleSignIn() async {
    if (_googleInitialized) return;
    // Flujo de nonce exigido por Supabase para `signInWithIdToken`:
    // 1. Generamos un nonce CRUDO aleatorio.
    // 2. Le pasamos a Google el nonce HASHEADO (SHA-256) — Google lo
    //    incrusta en el idToken que devuelve.
    // 3. Pasamos el nonce CRUDO a `signInWithIdToken` — Supabase lo
    //    hashea internamente y lo compara con el que viene en el
    //    idToken.
    _rawNonce = _generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(_rawNonce!)).toString();
    try {
      // ⚠️ En Web el SDK exige `clientId` (no `serverClientId`, que es
      // solo para plataformas nativas). Pasar `serverClientId` en Web
      // lanza: "serverClientId is not supported on Web."
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? SupabaseConfig.googleClientId : null,
        serverClientId: kIsWeb ? null : SupabaseConfig.googleClientId,
        nonce: hashedNonce,
      );
      _googleEventsSub = GoogleSignIn.instance.authenticationEvents.listen(
        _handleGoogleAuthEvent,
        onError: (Object e, StackTrace st) {
          lastError = 'Error de Google Sign-In: $e';
          notifyListeners();
        },
      );
      _googleInitialized = true;
      googleReady = true;
      notifyListeners();
    } catch (e) {
      lastError = 'No se pudo inicializar Google Sign-In: $e';
      notifyListeners();
    }
  }

  /// Único disparador posible en Web (Google exige el botón oficial
  /// ahí); en nativo también se usa desde [signInWithGoogle].
  Future<void> _handleGoogleAuthEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    final idToken = event.user.authentication.idToken;
    if (idToken == null) {
      lastError = 'Google no devolvió un idToken válido. Intenta de nuevo.';
      notifyListeners();
      return;
    }
    try {
      final response = await _client.auth.signInWithIdToken(
        provider: sb.OAuthProvider.google,
        idToken: idToken,
        nonce: _rawNonce,
      );
      if (response.user == null) {
        lastError = 'Supabase no devolvió un usuario válido.';
        notifyListeners();
      }
      // Si hay usuario, `onAuthStateChange` (escuchado en [init])
      // actualiza `_currentUser` y notifica automáticamente.
    } catch (e) {
      lastError = 'Error al validar sesión en Supabase: $e';
      notifyListeners();
    }
  }

  /// Login imperativo — solo funciona en plataformas nativas
  /// (Android/iOS). En Web usa [GoogleSignInButton] en su lugar.
  Future<void> signInWithGoogleNative() async {
    await prepareGoogleSignIn();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      lastError = 'En Web usa el botón oficial de Google.';
      notifyListeners();
      return;
    }
    try {
      await GoogleSignIn.instance.authenticate();
    } catch (e) {
      lastError = 'Error al iniciar sesión con Google: $e';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Ignorable si Google ya no tenía sesión activa.
    }
    await _client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  AppUser _mapUser(sb.User user) => AppUser(
    id: user.id,
    email: user.email ?? '',
    displayName: user.userMetadata?['full_name'] as String?,
    photoUrl: user.userMetadata?['avatar_url'] as String?,
  );

  @override
  void dispose() {
    _googleEventsSub?.cancel();
    _supabaseAuthSub?.cancel();
    super.dispose();
  }
}

String _generateRawNonce() {
  final random = Random.secure();
  return base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256)));
}
