import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/supabase_config.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await sb.Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  runApp(const ProsperaApp());
}

class ProsperaApp extends StatelessWidget {
  const ProsperaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(StorageService())..init(),
        ),
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()..init()),
        // IMPORTANTE: `lazy: false` es OBLIGATORIO aquí. Por defecto,
        // ProxyProvider solo instancia el valor la primera vez que algo
        // lo lee con `context.read`/`watch` — pero ningún widget del
        // árbol lee `CloudSyncService` directamente (solo se usa por
        // sus efectos secundarios, vía listeners). Sin `lazy: false`,
        // el servicio JAMÁS se creaba, sus listeners jamás se conectaban,
        // y la sincronización automática con la nube nunca ocurría — la
        // causa raíz de que los datos del usuario parecieran "perderse"
        // en cada nuevo deployment (quedaban solo en el almacenamiento
        // local del navegador, nunca subían a Supabase).
        ProxyProvider2<AuthService, AppState, CloudSyncService>(
          lazy: false,
          update: (_, auth, appState, previous) =>
              previous ?? CloudSyncService(auth: auth, appState: appState),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: Consumer2<AppState, AuthService>(
        builder: (context, state, auth, _) {
          return MaterialApp(
            title: 'Prospera',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: state.themeMode,
            home: state.loading
                ? const _SplashScreen()
                : (!auth.isSignedIn
                      ? const LoginScreen()
                      : (state.unlocked ? const HomeScreen() : const LockScreen())),
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.brandAmber),
      ),
    );
  }
}
