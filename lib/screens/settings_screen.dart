import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/collaborator.dart';
import '../models/enums.dart';
import '../services/export_import_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';
import 'manage_taxonomy_screen.dart';

const _uuid = Uuid();

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
          SectionTitle(title: 'Compartir acceso'),
          SectionCard(child: _ShareSection(state: state)),
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

/// Compartilhamento com 3 níveis de acesso (Propietario/Editor/Visualizador),
/// via convite (nombre+email) ou enlace seguro — todos trabajan sobre la
/// misma base de datos.
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
          'Comparte tu base de datos con otras personas, definiendo su nivel de acceso.',
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
              'Revocar enlace',
              style: TextStyle(color: AppColors.gasto),
            ),
          ),
        ] else
          ElevatedButton.icon(
            onPressed: () => state.generateShareLink(),
            icon: const Icon(Icons.link_rounded),
            label: const Text('Generar enlace seguro'),
          ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Colaboradores',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            TextButton.icon(
              onPressed: () => _inviteDialog(context),
              icon: const Icon(Icons.person_add_alt_rounded, size: 16),
              label: const Text('Invitar'),
            ),
          ],
        ),
        if (state.collaborators.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'Aún no invitaste a ningún colaborador.',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          )
        else
          ...state.collaborators.map((c) => _CollaboratorTile(collaborator: c)),
      ],
    );
  }

  Future<void> _inviteDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    ShareRole role = ShareRole.visualizador;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Invitar colaborador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ShareRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Nivel de acceso'),
                items: ShareRole.values
                    .where((r) => r != ShareRole.propietario)
                    .map(
                      (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                    )
                    .toList(),
                onChanged: (v) => setSt(() => role = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Invitar'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await state.addCollaborator(
        Collaborator(
          id: _uuid.v4(),
          name: nameCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          role: role,
        ),
      );
    }
  }
}

class _CollaboratorTile extends StatelessWidget {
  final Collaborator collaborator;
  const _CollaboratorTile({required this.collaborator});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.brandAmber.withValues(alpha: 0.2),
        child: Text(
          collaborator.name.isNotEmpty
              ? collaborator.name[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: AppColors.brandAmber,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        collaborator.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        collaborator.email,
        style: const TextStyle(fontSize: 11.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<ShareRole>(
            value: collaborator.role,
            underline: const SizedBox.shrink(),
            items: ShareRole.values
                .where((r) => r != ShareRole.propietario)
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(
                      r.label,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                )
                .toList(),
            onChanged: (r) {
              if (r != null) state.updateCollaboratorRole(collaborator.id, r);
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.gasto,
            ),
            onPressed: () => state.removeCollaborator(collaborator.id),
          ),
        ],
      ),
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
        const Divider(height: 1),
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
          leading: const Icon(
            Icons.download_outlined,
            color: AppColors.inversion,
          ),
          title: const Text('Importar datos (JSON)'),
          subtitle: const Text('Pega un backup JSON generado anteriormente'),
          onTap: () => _importDialog(context),
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

  Future<void> _importDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar datos (JSON)'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Pega aquí el JSON exportado',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (json != null && json.trim().isNotEmpty) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        await state.importSnapshot(data);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos importados correctamente')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('JSON inválido. Verifica el contenido pegado.'),
            ),
          );
        }
      }
    }
  }
}
