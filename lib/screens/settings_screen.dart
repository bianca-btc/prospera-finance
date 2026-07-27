import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
          SectionTitle(title: 'Seguridad'),
          SectionCard(child: _PinSection(state: state)),
          const SizedBox(height: AppSpacing.xl),
          SectionTitle(title: 'Datos'),
          SectionCard(child: _DataSection(state: state)),
        ],
      ),
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

class _PinSection extends StatelessWidget {
  final AppState state;
  const _PinSection({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.pin_rounded, color: AppColors.brandAmber),
          title: Text(state.hasPin ? 'PIN configurado' : 'Sin PIN'),
          subtitle: Text(
            state.hasPin
                ? 'Tu acceso local está protegido'
                : 'Protege el acceso a la app con un PIN de 4 dígitos',
          ),
          trailing: TextButton(
            onPressed: () => _setPinDialog(context),
            child: Text(state.hasPin ? 'Cambiar' : 'Configurar'),
          ),
        ),
        if (state.hasPin)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => state.setPin(null),
              child: const Text(
                'Quitar PIN',
                style: TextStyle(color: AppColors.gasto),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _setPinDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurar PIN'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(hintText: '4 dígitos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (pin != null && pin.length == 4) {
      await state.setPin(pin);
    }
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
