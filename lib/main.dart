import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/storage_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';

void main() {
  runApp(const ProsperaApp());
}

class ProsperaApp extends StatelessWidget {
  const ProsperaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(StorageService())..init(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Prospera',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: state.themeMode,
            home: state.loading
                ? const _SplashScreen()
                : (state.unlocked ? const HomeScreen() : const LockScreen()),
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
