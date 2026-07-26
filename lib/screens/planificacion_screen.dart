import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/budget_item.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/period.dart';
import '../widgets/common.dart';
import 'budget_form_screen.dart';
import 'debt_form_screen.dart';
import 'goal_form_screen.dart';

class PlanificacionScreen extends StatefulWidget {
  const PlanificacionScreen({super.key});

  @override
  State<PlanificacionScreen> createState() => _PlanificacionScreenState();
}

class _PlanificacionScreenState extends State<PlanificacionScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final periods = state.selectedPeriods;
    final budgets = state.budgets
        .where((b) => periods.contains(YearMonth(b.year, b.month)))
        // Los planes de Inversión/Deuda tienen su propia tarjeta especial
        // (_DebtTile/_GoalTile) más abajo — aquí solo se listan los planes
        // de Gasto normal (incluye "Otros").
        .where((b) => !b.isDebtInstallment && !b.isGoalContribution)
        .toList();
    final debts = state.debts;

    // Fuente única de verdad: mismo cálculo que usa el resto del app
    // (por budgetItemId, con fallback a categoría+subcategoría solo para
    // transacciones sin vínculo explícito) — evita duplicar lógica y
    // asegura que reasignar una transacción de "Otros" a otro plan
    // actualice ambos indicadores correctamente.
    double realizadoFor(BudgetItem b) => state.realizadoForBudgetItem(b);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenu(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva planificación'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          100,
        ),
        children: [
          if (state.hasPendingPlanificacion) ...[
            _PendingPlanificacionSection(state: state),
            const SizedBox(height: AppSpacing.xxl),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Presupuesto mensual',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                onSelected: (v) {
                  if (v == 'replicate') _showReplicateOptions(context, state);
                  if (v == 'suggest') _applySuggestion(context, state);
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'replicate',
                    child: Text('Replicar planificación'),
                  ),
                  PopupMenuItem(
                    value: 'suggest',
                    child: Text('Sugerir próximo mes'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (budgets.isEmpty)
            const SectionCard(
              child: Text('No hay presupuesto definido para este período.'),
            )
          else ...[
            const _PlanTableHeader(),
            const SizedBox(height: 6),
            ...budgets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _BudgetTile(item: b, realizado: realizadoFor(b)),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Deudas',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (debts.isEmpty)
            const SectionCard(child: Text('No hay deudas registradas.'))
          else ...[
            const _PlanTableHeader(realizadoLabel: 'Pagado'),
            const SizedBox(height: 6),
            ...debts.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _DebtTile(debt: d),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Objetivos de inversión',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.goals.isEmpty)
            const SectionCard(
              child: Text('No hay objetivos de inversión creados.'),
            )
          else ...[
            const _PlanTableHeader(
              plannedLabel: 'Meta',
              realizadoLabel: 'Acumulado',
            ),
            const SizedBox(height: 6),
            ...state.goals.map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _GoalTile(goal: g),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Único punto de entrada para crear una nueva Planificación: el usuario
  /// primero elige el TIPO (Gasto normal / Inversión / Deuda) — sustituye
  /// los 3 botones separados de antes por una sola acción "Nueva
  /// Planificación", reforzando que todo lo que aquí se crea es un plan
  /// ("por qué organizo mi dinero"), nunca un movimiento suelto.
  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Nueva Planificación',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                '¿Qué tipo de planificación quieres crear?',
                style: TextStyle(fontSize: 12.5, color: Colors.white70),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.request_page_outlined,
                color: AppColors.gasto,
              ),
              title: const Text('Gasto normal'),
              subtitle: const Text('Presupuesto mensual para una categoría'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BudgetFormScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: AppColors.inversion,
              ),
              title: const Text('Inversión'),
              subtitle: const Text('Meta de ahorro/inversión con aporte mensual'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GoalFormScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.account_balance_outlined,
                color: AppColors.deuda,
              ),
              title: const Text('Deuda'),
              subtitle: const Text('Deuda con cuotas mensuales automáticas'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebtFormScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Ponto de partida do fluxo de replicação: mostra as 5 opções previstas
  /// (próximo mes, varios meses consecutivos, meses específicos, año entero,
  /// selección manual). Todas terminam chamando [_confirmAndReplicate], que
  /// é o único caminho que efetivamente copia o planejamento — mantendo uma
  /// única fonte de verdade também para esta ação.
  void _showReplicateOptions(BuildContext context, AppState state) {
    final periods = state.selectedPeriods.toList()..sort();
    if (periods.isEmpty) return;
    final from = periods.last;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Replicar planificación de ${monthLabel(from)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward_rounded),
              title: const Text('Próximo mes'),
              subtitle: Text(monthLabel(from.next())),
              onTap: () {
                Navigator.pop(ctx);
                _confirmAndReplicate(context, state, from, [from.next()]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('Varios meses consecutivos'),
              onTap: () {
                Navigator.pop(ctx);
                _replicateConsecutive(context, state, from);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('Meses específicos'),
              onTap: () {
                Navigator.pop(ctx);
                _replicateSpecificMonths(context, state, from);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month_rounded),
              title: const Text('Año entero'),
              onTap: () {
                Navigator.pop(ctx);
                final targets = List.generate(12, (i) => from.addMonths(i + 1));
                _confirmAndReplicate(context, state, from, targets);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Selección manual'),
              onTap: () {
                Navigator.pop(ctx);
                _replicateManualSelection(context, state, from);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _replicateConsecutive(
    BuildContext context,
    AppState state,
    YearMonth from,
  ) async {
    final ctrl = TextEditingController(text: '3');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Varios meses consecutivos'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: '¿Cuántos meses?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text) ?? 0),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (n == null || n <= 0) return;
    final targets = List.generate(n, (i) => from.addMonths(i + 1));
    if (!context.mounted) return;
    await _confirmAndReplicate(context, state, from, targets);
  }

  Future<void> _replicateSpecificMonths(
    BuildContext context,
    AppState state,
    YearMonth from,
  ) async {
    final candidates = List.generate(24, (i) => from.addMonths(i + 1));
    final selected = <YearMonth>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Meses específicos'),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: ListView(
              children: candidates.map((ym) {
                final checked = selected.contains(ym);
                return CheckboxListTile(
                  value: checked,
                  title: Text(monthLabel(ym)),
                  onChanged: (v) => setLocal(() {
                    if (v == true) {
                      selected.add(ym);
                    } else {
                      selected.remove(ym);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selected.isEmpty) return;
    final targets = selected.toList()..sort();
    if (!context.mounted) return;
    await _confirmAndReplicate(context, state, from, targets);
  }

  Future<void> _replicateManualSelection(
    BuildContext context,
    AppState state,
    YearMonth from,
  ) async {
    final added = <YearMonth>[];
    var year = from.year;
    var month = from.next().month;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Selección manual'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: month,
                        decoration: const InputDecoration(labelText: 'Mes'),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(monthNamesEs[i + 1]),
                          ),
                        ),
                        onChanged: (v) => setLocal(() => month = v ?? month),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: year,
                        decoration: const InputDecoration(labelText: 'Año'),
                        items: List.generate(
                          6,
                          (i) => DropdownMenuItem(
                            value: from.year + i,
                            child: Text('${from.year + i}'),
                          ),
                        ),
                        onChanged: (v) => setLocal(() => year = v ?? year),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: () => setLocal(() {
                        final ym = YearMonth(year, month);
                        if (!added.contains(ym)) added.add(ym);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (added.isEmpty)
                  const Text('Ningún mes agregado todavía.')
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (added.toList()..sort()).map(
                      (ym) => Chip(
                        label: Text(monthLabel(ym)),
                        onDeleted: () => setLocal(() => added.remove(ym)),
                      ),
                    ).toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || added.isEmpty) return;
    final targets = added.toList()..sort();
    if (!context.mounted) return;
    await _confirmAndReplicate(context, state, from, targets);
  }

  /// Confirmação final e execução única — chamada por todos os fluxos de
  /// replicação acima, garantindo que a lógica de replicação em si exista
  /// em um único lugar (fonte única de verdade também no fluxo de UI).
  Future<void> _confirmAndReplicate(
    BuildContext context,
    AppState state,
    YearMonth from,
    List<YearMonth> targets,
  ) async {
    if (targets.isEmpty) return;
    final sorted = targets.toList()..sort();
    final label = sorted.length == 1
        ? monthLabel(sorted.first)
        : '${sorted.length} meses (${monthLabel(sorted.first)} – ${monthLabel(sorted.last)})';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replicar planificación'),
        content: Text(
          'Se copiará el presupuesto de ${monthLabel(from)} hacia $label. '
          'Las transacciones ejecutadas nunca se copian; cada mes quedará '
          'independiente después de la replicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replicar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.replicateBudgetToMany(from: from, targets: sorted);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Presupuesto replicado a $label.')),
        );
      }
    }
  }

  /// Aplica a sugestão automática de orçamento (baseada no histórico) para
  /// o mês seguinte ao último período selecionado — parte do "Planejamento
  /// Inteligente" que aprende com o histórico e sugere o próximo mês.
  Future<void> _applySuggestion(BuildContext context, AppState state) async {
    final periods = state.selectedPeriods.toList()..sort();
    final base = periods.isNotEmpty
        ? periods.last
        : YearMonth.fromDate(DateTime.now());
    final target = base.next();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sugerir próximo mes'),
        content: Text(
          'Con base en tu historial reciente, el sistema sugerirá automáticamente el presupuesto de ${monthLabel(target)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sugerir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.applyBudgetSuggestion(target);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Presupuesto de ${monthLabel(target)} sugerido automáticamente.',
            ),
          ),
        );
      }
    }
  }
}

/// Encabezado de columnas para las listas estilo tabla de Planificación:
/// alinea visualmente "Planificado"/"Realizado" a la derecha de cada
/// tarjeta, igual que el mockup de referencia, pero manteniendo las
/// tarjetas (no una tabla HTML rígida) para que sigan siendo táctiles y
/// expandibles en móvil.
class _PlanTableHeader extends StatelessWidget {
  final String plannedLabel;
  final String realizadoLabel;
  const _PlanTableHeader({
    this.plannedLabel = 'Planificado',
    this.realizadoLabel = 'Realizado',
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: Theme.of(context).textTheme.bodySmall?.color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text('CATEGORÍA', style: style)),
          SizedBox(
            width: 72,
            child: Text(
              plannedLabel.toUpperCase(),
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 72,
            child: Text(
              realizadoLabel.toUpperCase(),
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de estado ("Estado") con ícono + etiqueta, usada en las 3 tarjetas
/// (Gasto normal, Deuda, Inversión) para mostrar de un vistazo si un plan
/// está cubierto/al día, excedido, o pendiente — parte del rediseño estilo
/// tabla (columna "Estado" del mockup de referencia).
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatefulWidget {
  final BudgetItem item;
  final double realizado;
  const _BudgetTile({required this.item, required this.realizado});

  @override
  State<_BudgetTile> createState() => _BudgetTileState();
}

class _BudgetTileState extends State<_BudgetTile> {
  bool _expanded = false;

  Future<void> _confirmDeleteBudget(BuildContext context, BudgetItem b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar planificación?'),
        content: const Text(
          'Esto solo elimina el ítem de planificación. Las transacciones '
          'ya registradas NO se eliminan ni afectan tus KPIs — quedarán '
          'marcadas como "Pendente de planificación" para que puedas '
          'volver a organizarlas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.gasto),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // ignore: use_build_context_synchronously
      context.read<AppState>().deleteBudget(b.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.item;
    final realizado = widget.realizado;
    final diff = b.planned - realizado;
    final progress = b.planned <= 0 ? 0.0 : realizado / b.planned;
    final overflow = realizado > b.planned;
    final covered = b.planned > 0 && realizado >= b.planned - 0.01;
    // Color de la barra según el tipo de línea: azul para aportes de
    // inversión/objetivo, amarillo/naranja para cuotas de deuda,
    // rojo para gasto normal.
    final barColor = b.isGoalContribution
        ? AppColors.inversion
        : b.isDebtInstallment
            ? AppColors.deuda
            : AppColors.gasto;
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;

    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------- Fila estilo tabla: Categoría | Planificado | Realizado -------
            Row(
              children: [
                CategoryIcon(
                  iconKey: _iconKey(context, b.category),
                  color: barColor,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${b.category} · ${b.subcategory}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (b.autoSuggested)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: AppColors.inversion,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    formatUsd(b.planned, decimals: false),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12.5, color: mutedColor),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 72,
                  child: Text(
                    formatUsd(realizado, decimals: false),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: overflow ? AppColors.gasto : barColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ProgressBarWithOverflow(value: progress, color: barColor, height: 8),
            const SizedBox(height: 6),
            // ------- Meta-fila: Diferencia / Vencimiento / Prioridad / Estado -------
            Row(
              children: [
                Expanded(
                  child: Text(
                    overflow
                        ? 'Excedido +${formatUsd(-diff, decimals: false)}'
                        : 'Faltan ${formatUsd(diff, decimals: false)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: overflow ? FontWeight.w700 : FontWeight.w500,
                      color: overflow ? AppColors.gasto : mutedColor,
                    ),
                  ),
                ),
                if (b.dueDate != null) ...[
                  Text(
                    formatFullDate(b.dueDate!),
                    style: TextStyle(fontSize: 10.5, color: mutedColor),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                PriorityBadge(priority: b.priority),
                const SizedBox(width: AppSpacing.sm),
                overflow
                    ? const _StatusChip(
                        label: 'Excedido',
                        color: AppColors.gasto,
                        icon: Icons.priority_high_rounded,
                      )
                    : covered
                        ? _StatusChip(
                            label: 'Cubierto',
                            color: barColor,
                            icon: Icons.check_rounded,
                          )
                        : const _StatusChip(
                            label: 'En curso',
                            color: AppColors.warning,
                            icon: Icons.hourglass_bottom_rounded,
                          ),
                const SizedBox(width: 2),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 16,
                  color: mutedColor,
                ),
              ],
            ),
            if (_expanded) ...[
              const Divider(height: AppSpacing.lg),
              _DetailRow(label: 'País', value: b.country),
              _DetailRow(label: 'Método de pago', value: b.method.label),
              if (b.description.isNotEmpty) _DetailRow(label: 'Descripción', value: b.description),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BudgetFormScreen(existing: b),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDeleteBudget(context, b),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: AppColors.gasto,
                      ),
                      label: const Text(
                        'Eliminar',
                        style: TextStyle(color: AppColors.gasto),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _iconKey(BuildContext context, String category) {
    final state = context.read<AppState>();
    final match = state.expenseCategories.where((c) => c.name == category);
    return match.isNotEmpty ? match.first.icon : 'category';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  final Debt debt;
  const _DebtTile({required this.debt});

  /// "Realizar pago": permite un monto libre (pago parcial, adelanto, o
  /// la cuota completa) — pre-rellenado con la cuota mensual calculada.
  /// Nunca se crea como gasto manual; siempre queda vinculado a la deuda.
  Future<void> _showPayDialog(BuildContext context) async {
    final ctrl = TextEditingController(
      text: debt.monthlyInstallment > 0
          ? debt.monthlyInstallment.toStringAsFixed(2)
          : '',
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Realizar pago · ${debt.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Valor (USD)',
            prefixText: '\$ ',
            helperText:
                'Pendiente: ${formatUsd(debt.remainingAmount, decimals: false)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: const Text('Pagar'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0 && context.mounted) {
      await context.read<AppState>().payDebt(debt.id, amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = debt.progress;
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DebtFormScreen(existing: debt)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------- Fila estilo tabla: Nombre | Total | Pagado -------
            Row(
              children: [
                const CategoryIcon(
                  iconKey: 'account_balance',
                  color: AppColors.deuda,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    debt.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    formatUsd(debt.totalAmount, decimals: false),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12.5, color: mutedColor),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 72,
                  child: Text(
                    formatUsd(debt.paidAmount, decimals: false),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deuda,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ProgressBarWithOverflow(
              value: progress,
              color: AppColors.deuda,
              height: 8,
            ),
            const SizedBox(height: 6),
            // ------- Meta-fila: Restante / Cuotas / Estado / Acción -------
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Restante ${formatUsd(debt.remainingAmount, decimals: false)} · ${formatUsd(debt.monthlyInstallment, decimals: false)}/mes',
                    style: TextStyle(fontSize: 10.5, color: mutedColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                debt.isSettled
                    ? const _StatusChip(
                        label: 'Liquidada',
                        color: AppColors.ingreso,
                        icon: Icons.check_rounded,
                      )
                    : _StatusChip(
                        label: '${debt.paidInstallments}/${debt.months}',
                        color: AppColors.deuda,
                        icon: Icons.hourglass_bottom_rounded,
                      ),
              ],
            ),
            if (!debt.isSettled) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showPayDialog(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  child: const Text(
                    'Realizar pago',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final InvestmentGoal goal;
  const _GoalTile({required this.goal});

  Future<void> _showContributeDialog(BuildContext context) async {
    final ctrl = TextEditingController(
      text: goal.monthlyTarget > 0 ? goal.monthlyTarget.toStringAsFixed(2) : '',
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aportar a "${goal.name}"'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor (USD)',
            prefixText: '\$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: const Text('Aportar'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0 && context.mounted) {
      await context.read<AppState>().contributeToGoal(goal.id, amount);
    }
  }

  /// "Rescatar dinero": retira parte (o todo) el acumulado de la
  /// inversión. Nunca se crea como gasto manual; siempre disminuye el
  /// saldo de la inversión y aumenta el saldo disponible del usuario,
  /// dejando un movimiento en el historial (Rescate de inversión).
  Future<void> _showWithdrawDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rescatar de "${goal.name}"'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Valor (USD)',
            prefixText: '\$ ',
            helperText:
                'Disponible: ${formatUsd(goal.currentAmount, decimals: false)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: const Text('Rescatar'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0 && context.mounted) {
      await context.read<AppState>().withdrawFromGoal(goal.id, amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = goal.isCompleted;
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GoalFormScreen(existing: goal)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------- Fila estilo tabla: Nombre | Meta | Acumulado -------
            Row(
              children: [
                const CategoryIcon(
                  iconKey: 'trending_up',
                  color: AppColors.inversion,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    formatUsd(goal.targetAmount, decimals: false),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12.5, color: mutedColor),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 72,
                  child: Text(
                    formatUsd(goal.currentAmount, decimals: false),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.inversion,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ProgressBarWithOverflow(
              value: goal.progress,
              color: AppColors.inversion,
              height: 8,
            ),
            const SizedBox(height: 6),
            // ------- Meta-fila: Restante/Meta superada | Fecha final | Estado -------
            Row(
              children: [
                Expanded(
                  child: Text(
                    completed
                        ? (goal.isExceeded ? 'Meta superada' : 'Meta alcanzada')
                        : 'Restante ${formatUsd(goal.remaining, decimals: false)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: completed ? FontWeight.w700 : FontWeight.w500,
                      color: completed ? AppColors.ingreso : mutedColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (goal.targetDate != null) ...[
                  Text(
                    formatFullDate(goal.targetDate!),
                    style: TextStyle(fontSize: 10.5, color: mutedColor),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                completed
                    ? const _StatusChip(
                        label: 'Completa',
                        color: AppColors.ingreso,
                        icon: Icons.check_rounded,
                      )
                    : const _StatusChip(
                        label: 'En curso',
                        color: AppColors.inversion,
                        icon: Icons.hourglass_bottom_rounded,
                      ),
              ],
            ),
            if (!completed) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showContributeDialog(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: const Text(
                        'Aportar',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ),
                  if (goal.currentAmount > 0) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showWithdrawDialog(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          side: const BorderSide(color: AppColors.gasto),
                        ),
                        child: const Text(
                          'Rescatar',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.gasto,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Seção destacada "⚠ Transações pendentes", exibida ACIMA da lista de
/// planificaciones. Só aparece quando existem transações que perderam seu
/// vínculo com uma planificación (geralmente porque essa planificación foi
/// excluída). Vincular uma transação NUNCA altera nenhum KPI — é puramente
/// uma ação de organização.
class _PendingPlanificacionSection extends StatefulWidget {
  final AppState state;
  const _PendingPlanificacionSection({required this.state});

  @override
  State<_PendingPlanificacionSection> createState() =>
      _PendingPlanificacionSectionState();
}

class _PendingPlanificacionSectionState
    extends State<_PendingPlanificacionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final pending = state.txnsPendingPlanificacion;
    final count = pending.length;
    final total = state.pendingPlanificacionTotal;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transações pendentes',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count transaç${count == 1 ? 'ão precisa' : 'ões precisam'} '
                          'de ser vinculada${count == 1 ? '' : 's'} a uma planificación',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatUsd(total, decimals: false),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'organizar',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warning.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 18,
                            color: AppColors.warning,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: pending
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _PendingTxnTile(txn: t, state: state),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tile de uma transação pendente individual — permite vincular a uma
/// planificación existente do mesmo mês/tipo, ou criar uma nova e vincular
/// imediatamente. Uma vez vinculada, desaparece automaticamente da lista.
class _PendingTxnTile extends StatelessWidget {
  final Txn txn;
  final AppState state;
  const _PendingTxnTile({required this.txn, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${txn.category} · ${txn.subcategory}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatUsd(txn.amount, decimals: false)} · ${txn.movementTypeLabel}',
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => _showLinkOptions(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              side: const BorderSide(color: AppColors.warning),
            ),
            child: const Text(
              'Vincular',
              style: TextStyle(fontSize: 11.5, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  void _showLinkOptions(BuildContext context) {
    final ym = YearMonth(txn.year, txn.month);
    // Solo se sugieren planificaciones de Gasto normal del mismo mes que
    // encajen con el tipo de la transacción; deudas/objetivos ya tienen
    // sus propios vínculos automáticos (debtId/goalId) y no aparecen aquí.
    final candidates = state.budgets
        .where(
          (b) =>
              b.year == ym.year &&
              b.month == ym.month &&
              !b.isDebtInstallment &&
              !b.isGoalContribution,
        )
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vincular transação',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${txn.category} · ${txn.subcategory} · '
                '${formatUsd(txn.amount, decimals: false)}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.md),
              if (candidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Não há planificaciones existentes neste mês. '
                    'Crie uma nova para vincular esta transação.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView(
                    shrinkWrap: true,
                    children: candidates
                        .map(
                          (b) => ListTile(
                            leading: const Icon(
                              Icons.link_rounded,
                              color: AppColors.gasto,
                            ),
                            title: Text('${b.category} · ${b.subcategory}'),
                            subtitle: Text(
                              formatUsd(b.planned, decimals: false),
                            ),
                            onTap: () {
                              state.linkTxnToBudget(txn.id, b.id);
                              Navigator.pop(ctx);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Criar nova planificação e vincular'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final created = await Navigator.of(context).push<BudgetItem>(
                      MaterialPageRoute(
                        builder: (_) => BudgetFormScreen(
                          initialMonth: ym.month,
                          initialYear: ym.year,
                          initialCategory: txn.category,
                          initialSubcategory: txn.subcategory,
                          initialPlanned: txn.amount,
                        ),
                      ),
                    );
                    if (created != null) {
                      state.linkTxnToBudget(txn.id, created.id);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
