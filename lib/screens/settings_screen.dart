import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
                  'Control financiero personal',
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
          SectionTitle(title: 'Acceso compartido'),
          SectionCard(child: _ShareSection(state: state)),
          const SizedBox(height: AppSpacing.xl),
          SectionTitle(title: 'Datos'),
          SectionCard(child: _DataSection(state: state)),
        ],
      ),
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

class _ShareSection extends StatelessWidget {
  final AppState state;
  const _ShareSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final token = state.shareToken;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genera un enlace exclusivo para dar acceso a otra persona a tus datos de Prospera. '
          'Por ahora el enlace queda registrado localmente como identificador de autorización; '
          'la sincronización remota entre dispositivos estará disponible cuando se conecte un backend.',
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (token != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'prospera://share/$token',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: 'prospera://share/$token'),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enlace copiado al portapapeles'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => state.revokeShareLink(),
            child: const Text(
              'Revocar acceso',
              style: TextStyle(color: AppColors.gasto),
            ),
          ),
        ] else
          ElevatedButton.icon(
            onPressed: () => state.generateShareLink(),
            icon: const Icon(Icons.link_rounded),
            label: const Text('Generar enlace de acceso'),
          ),
      ],
    );
  }
}

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
            Icons.upload_file_outlined,
            color: AppColors.brandAmber,
          ),
          title: const Text('Exportar datos (JSON)'),
          subtitle: const Text('Copia todos los datos al portapapeles'),
          onTap: () {
            final data = jsonEncode(state.exportSnapshot());
            Clipboard.setData(ClipboardData(text: data));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Datos copiados al portapapeles')),
            );
          },
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restore_rounded, color: AppColors.gasto),
          title: const Text('Restaurar datos originales'),
          subtitle: const Text(
            'Reinicia el app con los datos base (El Salvador)',
          ),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Restaurar datos'),
                content: const Text(
                  'Esto eliminará todas tus transacciones, presupuestos y objetivos actuales, y volverá a cargar los datos originales. ¿Continuar?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Restaurar'),
                  ),
                ],
              ),
            );
            if (ok == true) await state.resetToSeed();
          },
        ),
      ],
    );
  }
}
