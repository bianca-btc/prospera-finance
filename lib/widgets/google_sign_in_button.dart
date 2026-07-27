// Botón de "Iniciar sesión con Google" — usa una implementación
// distinta según la plataforma:
// - Web: botón oficial renderizado por el SDK de Google (requerido
//   por Google Identity Services, no se puede reemplazar por un
//   botón propio).
// - Android/otras: botón normal de Material que llama a
//   `signInWithGoogleNative()`.
export 'google_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_button_web.dart';
