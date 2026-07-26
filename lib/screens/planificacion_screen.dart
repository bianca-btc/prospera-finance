import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/budget_item.dart';
import '../models/debt.dart';
import '../models/goal.dart';
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
          else
            ...budgets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _BudgetTile(item: b, realizado: realizadoFor(b)),
              ),
            ),
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
          else
            ...debts.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _DebtTile(debt: d),
              ),
            ),
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
          else
            ...state.goals.map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _GoalTile(goal: g),
              ),
            ),
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
                color: AppColors.inversion,
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

class _BudgetTile extends StatefulWidget {
  final BudgetItem item;
  final double realizado;
  const _BudgetTile({required this.item, required this.realizado});

  @override
  State<_BudgetTile> createState() => _BudgetTileState();
}

class _BudgetTileState extends State<_BudgetTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.item;
    final realizado = widget.realizado;
    final diff = b.planned - realizado;
    final progress = b.planned <= 0 ? 0.0 : realizado / b.planned;
    final overflow = realizado > b.planned;
    // Color de la barra según el tipo de línea: azul para aportes de
    // inversión/objetivo, rojo para gasto/deuda — igual criterio pedido
    // para las transacciones.
    final barColor = b.isGoalContribution
        ? AppColors.inversion
        : AppColors.gasto;

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
            Row(
              children: [
                CategoryIcon(
                  iconKey: _iconKey(context, b.category),
                  color: barColor,
                  size: 36,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${b.category} · ${b.subcategory}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (b.autoSuggested)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 14,
                                color: AppColors.inversion,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Realizado destacado (bold, coloreado) vs. Planificado
                      // en segundo plano — más fácil de leer de un vistazo
                      // que la versión anterior (texto plano concatenado).
                      Row(
                        children: [
                          Text(
                            formatUsd(realizado, decimals: false),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: overflow ? AppColors.gasto : barColor,
                            ),
                          ),
                          Text(
                            ' de ${formatUsd(b.planned, decimals: false)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PriorityBadge(priority: b.priority),
                    const SizedBox(height: 4),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ProgressBarWithOverflow(value: progress, color: barColor, height: 10),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  overflow
                      ? '¡Excedido! +${formatUsd(-diff, decimals: false)}'
                      : '${(progress * 100).clamp(0, 999).toStringAsFixed(0)}% · faltan ${formatUsd(diff, decimals: false)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: overflow ? FontWeight.w700 : FontWeight.w500,
                    color: overflow
                        ? AppColors.gasto
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                if (b.dueDate != null)
                  Text(
                    'Vence ${formatFullDate(b.dueDate!)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
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
                      onPressed: () =>
                          context.read<AppState>().deleteBudget(b.id),
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
    return SectionCard(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DebtFormScreen(existing: debt)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CategoryIcon(
                  iconKey: 'account_balance',
                  color: AppColors.inversion,
                  size: 36,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatUsd(debt.monthlyInstallment, decimals: false)}/mes · ${debt.paidInstallments}/${debt.months} cuotas',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (debt.isSettled)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.ingreso,
                    size: 20,
                  )
                else
                  OutlinedButton(
                    onPressed: () => _showPayDialog(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    child: const Text(
                      'Realizar pago',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ProgressBarWithOverflow(
              value: progress,
              color: AppColors.inversion,
            ),
            const SizedBox(height: 6),
            Text(
              'Restante ${formatUsd(debt.remainingAmount, decimals: false)} de ${formatUsd(debt.totalAmount, decimals: false)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
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
    return SectionCard(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GoalFormScreen(existing: goal)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CategoryIcon(
                  iconKey: 'trending_up',
                  color: AppColors.inversion,
                  size: 36,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Acumulado ${formatUsd(goal.currentAmount, decimals: false)} de ${formatUsd(goal.targetAmount, decimals: false)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (completed)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.ingreso,
                    size: 20,
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _showContributeDialog(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 30),
                        ),
                        child: const Text(
                          'Aportar',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                      if (goal.currentAmount > 0) ...[
                        const SizedBox(height: 4),
                        OutlinedButton(
                          onPressed: () => _showWithdrawDialog(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 30),
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
                      ],
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ProgressBarWithOverflow(
              value: goal.progress,
              color: AppColors.inversion,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  completed
                      ? (goal.isExceeded ? 'Meta superada' : 'Meta concluida')
                      : 'Restante ${formatUsd(goal.remaining, decimals: false)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: completed ? FontWeight.w700 : FontWeight.w400,
                    color: completed
                        ? AppColors.ingreso
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                if (goal.targetDate != null)
                  Text(
                    'Meta: ${formatFullDate(goal.targetDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
