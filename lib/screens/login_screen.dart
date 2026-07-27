import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/google_sign_in_button.dart';

/// Tela de login: única porta de entrada para autenticação e
/// sincronização de dados. Sem contas de convidado/demo — apenas
/// login com Google (que ativa sincronização automática via
/// [CloudSyncService]).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(size: 72),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Prospera',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Inicia sesión para sincronizar tus datos',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const GoogleSignInButton(),
                  if (auth.lastError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      auth.lastError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.gasto),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
