import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/budget_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/period.dart';
import '../widgets/common.dart';
import 'budget_form_screen.dart';
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
        .toList();
    final txns = state.txnsForSelectedPeriods;

    // Agrupa realizado por categoria+subcategoria (apenas gastos/deudas).
    double realizadoFor(BudgetItem b) {
      return txns
          .where(
            (t) =>
                (t.type == TxType.gasto || t.type == TxType.deuda) &&
                t.category == b.category &&
                t.subcategory == b.subcategory,
          )
          .fold(0.0, (s, t) => s + t.amount);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenu(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
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
              TextButton.icon(
                onPressed: () => _replicateMonth(context, state),
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: const Text('Replicar mes'),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Objetivos de inversión',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
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

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.request_page_outlined,
                color: AppColors.gasto,
              ),
              title: const Text('Nuevo ítem de presupuesto'),
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
              title: const Text('Nuevo objetivo de inversión'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GoalFormScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _replicateMonth(BuildContext context, AppState state) async {
    final periods = state.selectedPeriods.toList()..sort();
    if (periods.isEmpty) return;
    final from = periods.last;
    final to = from.next();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replicar mes'),
        content: Text(
          'Se copiará el presupuesto de ${monthLabel(from)} hacia ${monthLabel(to)}.',
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
      await state.replicateBudgetMonth(from: from, to: to);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Presupuesto replicado a ${monthLabel(to)}.')),
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
                  color: AppColors.gasto,
                  size: 36,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${b.category} · ${b.subcategory}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Planificado ${formatUsd(b.planned, decimals: false)} · Realizado ${formatUsd(realizado, decimals: false)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      diff >= 0
                          ? '-${formatUsd(diff, decimals: false)} restante'
                          : '+${formatUsd(-diff, decimals: false)} excedido',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: diff >= 0 ? AppColors.ingreso : AppColors.gasto,
                      ),
                    ),
                    const SizedBox(height: 4),
                    PriorityBadge(priority: b.priority),
                  ],
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ProgressBarWithOverflow(value: progress, color: AppColors.gasto),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).clamp(0, 999).toStringAsFixed(0)}% del presupuesto',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                if (overflow)
                  const Text(
                    '¡Excedido!',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.gasto,
                      fontWeight: FontWeight.w600,
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
                StatusBadge(status: b.status),
              ],
            ),
            if (_expanded) ...[
              const Divider(height: AppSpacing.lg),
              _DetailRow(label: 'Naturaleza', value: b.nature.label),
              _DetailRow(label: 'País', value: b.country),
              _DetailRow(label: 'Método de pago', value: b.method.label),
              if (b.description.isNotEmpty)
                _DetailRow(label: 'Descripción', value: b.description),
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

class _GoalTile extends StatelessWidget {
  final InvestmentGoal goal;
  const _GoalTile({required this.goal});

  @override
  Widget build(BuildContext context) {
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
                Text(
                  '${(goal.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppColors.inversion,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
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
                  'Restante ${formatUsd(goal.remaining, decimals: false)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
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
