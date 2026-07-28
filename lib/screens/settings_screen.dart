import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/export_import_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';
import 'manage_taxonomy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          Center(
            child: Column(
              children: [
                const AppLogo(size: 56),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Prospera',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Asistente financiero personal',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SectionTitle(title: 'Apariencia'),
          SectionCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tema oscuro'),
              subtitle: const Text(
                'Activa o desactiva el tema oscuro de la app',
              ),
              value: state.themeMode == ThemeMode.dark,
              onChanged: (_) => state.toggleTheme(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionTitle(title: 'Personalización del Resumen'),
          SectionCard(child: _CardVisibilitySection(state: state)),
          const SizedBox(height: AppSpacing.xl),
          SectionTitle(title: 'Categorías y ubicaciones'),
          SectionCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.trending_down_rounded,
                    color: AppColors.gasto,
                  ),
                  title: const Text('Categorías de gastos/deudas'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const ManageTaxonomyScreen(isExpense: true),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.ingreso,
                  ),
                  title: const Text('Categorías de ingresos'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const ManageTaxonomyScreen(isExpense: false),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.public_rounded,
                    color: AppColors.brandAmber,
                  ),
                  title: const Text('Países / Ubicaciones'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManageCountriesScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionTitle(title: 'Datos'),
          SectionCard(child: _DataSection(state: state)),
          const SizedBox(height: AppSpacing.xl),
          SectionTitle(title: 'Cuenta'),
          SectionCard(child: const _AccountSection()),
        ],
      ),
    );
  }
}

/// Cierre de sesión: termina la sesión de Supabase Auth (y de Google, si
/// corresponde) y redirige automáticamente a la pantalla de login — el
/// gate en `main.dart` (`!auth.isSignedIn ? LoginScreen() : ...`) reacciona
/// solo al cambio de estado de [AuthService], sin necesidad de navegación
/// manual.
class _AccountSection extends StatelessWidget {
  const _AccountSection();

  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir de la cuenta'),
        content: const Text('¿Deseas cerrar tu sesión actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Salir',
              style: TextStyle(color: AppColors.gasto),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await auth.signOut();
    }
  }

  String _formatSyncTime(DateTime? dt) {
    if (dt == null) return 'nunca';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 10) return 'ahora mismo';
    if (diff.inMinutes < 1) return 'hace ${diff.inSeconds}s';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'hace ${diff.inHours} h';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<CloudSyncService>();
    final hasError = sync.lastError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (auth.currentUser != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.account_circle_rounded,
              color: AppColors.brandAmber,
            ),
            title: Text(
              auth.currentUser!.displayName?.isNotEmpty == true
                  ? auth.currentUser!.displayName!
                  : auth.currentUser!.email,
            ),
            subtitle: Text(auth.currentUser!.email),
          ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            sync.isSyncing
                ? Icons.sync_rounded
                : hasError
                    ? Icons.sync_problem_rounded
                    : Icons.cloud_done_rounded,
            color: sync.isSyncing
                ? AppColors.brandAmber
                : hasError
                    ? AppColors.gasto
                    : AppColors.ingreso,
          ),
          title: Text(
            sync.isSyncing
                ? 'Sincronizando...'
                : hasError
                    ? 'Error al sincronizar'
                    : 'Copia de seguridad en la nube',
          ),
          subtitle: Text(
            hasError && !sync.isSyncing
                ? sync.lastError!
                : 'Última sincronización: ${_formatSyncTime(sync.lastSyncedAt)}',
            style: hasError && !sync.isSyncing
                ? const TextStyle(color: AppColors.gasto)
                : null,
          ),
          trailing: sync.isSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Sincronizar ahora',
                  onPressed: () async {
                    await sync.uploadNow();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            sync.lastError != null
                                ? 'Error: ${sync.lastError}'
                                : 'Datos sincronizados correctamente',
                          ),
                        ),
                      );
                    }
                  },
                ),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_rounded, color: AppColors.gasto),
          title: const Text(
            'Salir de la cuenta (Logout)',
            style: TextStyle(color: AppColors.gasto, fontWeight: FontWeight.w600),
          ),
          onTap: () => _confirmSignOut(context),
        ),
      ],
    );
  }
}

/// Personalização: o usuário escolhe quais cards aparecem no Resumen.
class _CardVisibilitySection extends StatelessWidget {
  final AppState state;
  const _CardVisibilitySection({required this.state});

  String _labelFor(String key) {
    switch (key) {
      case 'resumo_inteligente':
        return 'Resumen inteligente';
      case 'principales_gastos':
        return 'Principales gastos';
      case 'proximos_vencimientos':
        return 'Próximos vencimientos';
      case 'objetivos':
        return 'Objetivos financieros';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: allResumenCardKeys
          .map(
            (key) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_labelFor(key)),
              value: state.visibleCards.contains(key),
              onChanged: (_) => state.toggleCardVisible(key),
            ),
          )
          .toList(),
    );
  }
}

/// Exportação/importação completa (arquitetura CSV/TXT), cobrindo todas as
/// entidades do app (Transações, Planejamento, Objetivos, Dívidas,
/// Categorias, Subcategorias, Países, Permissões e Configurações).
class _DataSection extends StatelessWidget {
  final AppState state;
  const _DataSection({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.description_outlined,
            color: AppColors.brandAmber,
          ),
          title: const Text('Exportar todo (TXT/CSV)'),
          subtitle: const Text(
            'Transacciones, planificación, objetivos, deudas y más',
          ),
          onTap: () {
            final data = ExportImportService.fullExportTxt(state);
            Clipboard.setData(ClipboardData(text: data));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Datos copiados al portapapeles (formato TXT/CSV)',
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
