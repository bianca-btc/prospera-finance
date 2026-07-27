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
        ProxyProvider2<AuthService, AppState, CloudSyncService>(
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
