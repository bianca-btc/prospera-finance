/// Configuración del proyecto Supabase de Prospera Finance.
///
/// Estas credenciales son públicas por diseño (clave "publishable"/anon,
/// nunca la service_role) — la seguridad real la da Row Level Security
/// en Postgres (ver `supabase/schema.sql`: cada fila solo es visible
/// para su propio `user_id = auth.uid()`).
class SupabaseConfig {
  static const String url = 'https://hurtgkuyvfmbesamehcq.supabase.co';
  static const String anonKey =
      'sb_publishable_tAOEygOjJ7CBYo2ZssaS4w_Jn2b_2nX';

  /// Client ID de Google (tipo "Aplicación web") usado tanto para el
  /// botón de Google Sign-In en Web como para el flujo nativo en
  /// Android. Debe coincidir con el configurado en Supabase →
  /// Authentication → Providers → Google.
  static const String googleClientId =
      '1032056798967-1qu9730jirk7rhurehvlsu4hpd8g3oin.apps.googleusercontent.com';

  /// Única tabla de datos: guarda un snapshot JSON completo por
  /// usuario (ver `supabase/schema.sql`). No hay tablas relacionales
  /// por entidad — se reutiliza el mismo formato que ya produce
  /// `StorageService.exportAll()` / consume `importAll()`.
  static const String userDataTable = 'user_data';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
