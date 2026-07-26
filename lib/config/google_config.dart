/// Configuración del OAuth Client ID de Google usado para Google
/// Sign-In + Google Sheets (backup automático de todos los datos de
/// Prospera en una hoja de cálculo de la cuenta Google del usuario).
///
/// ⚠️ SIN ESTE VALOR, LA SINCRONIZACIÓN CON GOOGLE PERMANECE
/// DESACTIVADA (el resto de la app sigue funcionando 100% en modo
/// local, como hasta ahora). La pantalla de Ajustes mostrará
/// instrucciones si este valor está vacío.
///
/// ───────────────────────────────────────────────────────────────
/// CÓMO OBTENERLO (una sola vez, es gratis, dura ~10 minutos):
/// ───────────────────────────────────────────────────────────────
/// 1. Entra a https://console.cloud.google.com/ con tu cuenta Google
///    y crea un proyecto nuevo (o usa uno existente).
/// 2. Ve a "APIs y servicios" → "Biblioteca" y habilita:
///      • Google Sheets API
///      • Google Drive API
/// 3. Ve a "APIs y servicios" → "Pantalla de consentimiento OAuth":
///      • Tipo de usuario: Externo
///      • Completa nombre de la app, correo de soporte, etc.
///      • Si queda en modo "Prueba", agrega tu propio correo como
///        "Usuario de prueba" (así podrás usarla sin publicarla).
/// 4. Ve a "APIs y servicios" → "Credenciales" → "Crear credenciales"
///    → "ID de cliente de OAuth" → Tipo de aplicación: **Aplicación
///    web**.
/// 5. En "Orígenes autorizados de JavaScript" agrega la(s) URL(s)
///    donde se sirve la app (por ejemplo, la URL de vista previa que
///    usas ahora, y luego el dominio final cuando publiques).
/// 6. Guarda y copia el "ID de cliente" (termina en
///    ".apps.googleusercontent.com") y pégalo abajo.
///
/// Este mismo Client ID (tipo "Aplicación web") funciona tanto para
/// la vista previa Web como para el APK de Android (se usa como
/// `serverClientId` en Android, tal como indica la documentación
/// oficial de google_sign_in).
const String googleOAuthClientId = '';
