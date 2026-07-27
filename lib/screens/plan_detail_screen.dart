import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/budget_item.dart';
import '../models/debt.dart';
import '../models/enums.dart';
import '../models/goal.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'plan_form_screen.dart';

/// Ação rápida disponível na tela de Detalhes do Plano (Aportar/Retirar/
/// Pagar/Estender prazo, dependendo do tipo de plano).
class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// Pantalla dedicada "Detalhes do Plano" — reemplaza la expansión inline
/// dentro de las tarjetas de Planificación. Unifica los 3 tipos de plano
/// (Gasto/Deuda/Objetivo) en un mismo layout: anillo de progreso, stats
/// resumidos, acciones rápidas (según el tipo) e historial de movimientos
/// vinculados — siguiendo el mockup "DETALHES DO PLANO".
class PlanDetailScreen extends StatefulWidget {
  final BudgetItem? budget;
  final Debt? debt;
  final InvestmentGoal? goal;

  const PlanDetailScreen.budget(BudgetItem item, {super.key})
      : budget = item,
        debt = null,
        goal = null;

  const PlanDetailScreen.debt(Debt d, {super.key})
      : budget = null,
        debt = d,
        goal = null;

  const PlanDetailScreen.goal(InvestmentGoal g, {super.key})
      : budget = null,
        debt = null,
        goal = g;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  Future<void> _confirmDelete(
    BuildContext context,
    AppState state, {
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.gasto)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onConfirm();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<double?> _showAmountDialog(
    BuildContext context, {
    required String title,
    String? helperText,
    String initial = '',
    String confirmLabel = 'Confirmar',
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Valor (USD)',
            prefixText: '\$ ',
            helperText: helperText,
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
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (widget.goal != null) return _buildGoal(context, state, widget.goal!);
    if (widget.debt != null) return _buildDebt(context, state, widget.debt!);
    return _buildBudget(context, state, widget.budget!);
  }

  // ---------------------------------------------------------------- Objetivo
  Widget _buildGoal(BuildContext context, AppState state, InvestmentGoal goal) {
    final ratio = goal.progress;
    final completed = goal.isCompleted;
    final daysRemaining = goal.targetDate?.difference(DateTime.now()).inDays;
    final expired = daysRemaining != null && daysRemaining < 0 && !completed;

    return _DetailScaffold(
      title: goal.name,
      badgeLabel: 'Objetivo',
      badgeColor: AppColors.inversion,
      subtitle: goal.targetDate != null
          ? 'Termina em ${formatFullDate(goal.targetDate!)}'
          : null,
      ringPercent: ratio,
      ringColor: AppColors.inversion,
      leftStatLabel: 'Guardado',
      leftStatValue: formatUsd(goal.currentAmount, decimals: false),
      rightStatLabel: completed ? 'Meta superada' : 'Falta',
      rightStatValue: completed
          ? formatUsd(goal.currentAmount - goal.targetAmount, decimals: false)
          : formatUsd(goal.remaining, decimals: false),
      metaLabel: 'Meta',
      metaValue: formatUsd(goal.targetAmount, decimals: false),
      daysLabel: 'Dias restantes',
      daysValue: daysRemaining == null
          ? '—'
          : expired
              ? 'Vencido'
              : '$daysRemaining dias',
      expiredWarning: expired
          ? 'El objetivo "${goal.name}" venció y aún no fue alcanzado. '
              'Considera extender la fecha o aumentar los aportes.'
          : null,
      quickActions: [
        _QuickAction(
          label: 'Aportar dinero',
          icon: Icons.add_circle_outline_rounded,
          color: AppColors.inversion,
          onTap: () async {
            final amount = await _showAmountDialog(
              context,
              title: 'Aportar a "${goal.name}"',
              initial: goal.monthlyTarget > 0
                  ? goal.monthlyTarget.toStringAsFixed(2)
                  : '',
              confirmLabel: 'Aportar',
            );
            if (amount != null && amount > 0 && context.mounted) {
              await context.read<AppState>().contributeToGoal(goal.id, amount);
            }
          },
        ),
        _QuickAction(
          label: 'Retirar dinero',
          icon: Icons.remove_circle_outline_rounded,
          color: AppColors.gasto,
          onTap: () async {
            final amount = await _showAmountDialog(
              context,
              title: 'Rescatar de "${goal.name}"',
              helperText:
                  'Disponible: ${formatUsd(goal.currentAmount, decimals: false)}',
              confirmLabel: 'Rescatar',
            );
            if (amount != null && amount > 0 && context.mounted) {
              await context.read<AppState>().withdrawFromGoal(goal.id, amount);
            }
          },
        ),
        _QuickAction(
          label: 'Extender plazo',
          icon: Icons.event_repeat_rounded,
          color: AppColors.warning,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: (goal.targetDate ?? DateTime.now())
                  .add(const Duration(days: 30)),
        firstDate: DateTime.now(),
              lastDate: DateTime(2045),
            );
            if (picked != null && context.mounted) {
              await context
                  .read<AppState>()
                  .updateGoal(goal.copyWith(targetDate: picked));
            }
          },
        ),
      ],
      infoRows: [
        PlanDetailRow(label: 'País', value: goal.country),
        if (goal.description.isNotEmpty)
          PlanDetailRow(label: 'Descripción', value: goal.description),
      ],
      historyTitle: 'Historial de movimientos',
      txns: state.txnsForGoal(goal.id),
      onEdit: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlanFormScreen.editGoal(goal)),
      ),
      onDelete: () => _confirmDelete(
        context,
        state,
        title: '¿Eliminar objetivo?',
        message:
            'Esto solo elimina el objetivo de inversión. Las transacciones ya '
            'registradas (aportes/rescates) NO se eliminan ni afectan tus KPIs '
            '— quedarán marcadas como "Pendente de planificación" para que '
            'puedas volver a organizarlas.',
        onConfirm: () => state.deleteGoal(goal.id),
      ),
    );
  }

  // ------------------------------------------------------------------ Deuda
  Widget _buildDebt(BuildContext context, AppState state, Debt debt) {
    final ratio = debt.progress;
    return _DetailScaffold(
      title: debt.name,
      badgeLabel: 'Deuda',
      badgeColor: AppColors.warning,
      subtitle: '${debt.paidInstallments}/${debt.months} cuotas',
      ringPercent: ratio,
      ringColor: AppColors.warning,
      leftStatLabel: 'Pago',
      leftStatValue: formatUsd(debt.paidAmount, decimals: false),
      rightStatLabel: 'Falta',
      rightStatValue: formatUsd(debt.remainingAmount, decimals: false),
      metaLabel: 'Total',
      metaValue: formatUsd(debt.totalAmount, decimals: false),
      daysLabel: 'Cuota mensual',
      daysValue: formatUsd(debt.monthlyInstallment, decimals: false),
      quickActions: debt.isSettled
          ? []
          : [
              _QuickAction(
                label: 'Realizar pago',
                icon: Icons.payments_outlined,
                color: AppColors.warning,
                onTap: () async {
                  final amount = await _showAmountDialog(
                    context,
                    title: 'Realizar pago · ${debt.name}',
                    initial: debt.monthlyInstallment > 0
                        ? debt.monthlyInstallment.toStringAsFixed(2)
                        : '',
                    helperText:
                        'Pendiente: ${formatUsd(debt.remainingAmount, decimals: false)}',
                    confirmLabel: 'Pagar',
                  );
                  if (amount != null && amount > 0 && context.mounted) {
                    await context.read<AppState>().payDebt(debt.id, amount);
                  }
                },
              ),
            ],
      infoRows: [
        PlanDetailRow(label: 'País', value: debt.country),
        PlanDetailRow(
          label: 'Categoría',
          value: '${debt.category} · ${debt.subcategory}',
        ),
        if (debt.description.isNotEmpty)
          PlanDetailRow(label: 'Descripción', value: debt.description),
      ],
      historyTitle: 'Histórico de pagos',
      txns: state.txnsForDebt(debt.id),
      onEdit: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlanFormScreen.editDebt(debt)),
      ),
      onDelete: () => _confirmDelete(
        context,
        state,
        title: '¿Eliminar deuda?',
        message:
            'Esto solo elimina la deuda y sus cuotas planificadas. Las '
            'transacciones ya registradas (pagos ya hechos) NO se eliminan '
            'ni afectan tus KPIs — quedarán marcadas como "Pendente de '
            'planificación" para que puedas volver a organizarlas.',
        onConfirm: () => state.deleteDebt(debt.id),
      ),
    );
  }

  // ------------------------------------------------------------------ Gasto
  Widget _buildBudget(BuildContext context, AppState state, BudgetItem b) {
    final realizado = state.realizadoForBudgetItem(b);
    final ratio = b.planned <= 0 ? 0.0 : realizado / b.planned;
    final overflow = realizado > b.planned;
    return _DetailScaffold(
      title: '${b.category} · ${b.subcategory}',
      badgeLabel: 'Gasto',
      badgeColor: AppColors.gasto,
      subtitle: b.dueDate != null
          ? 'Vencimiento: ${formatFullDate(b.dueDate!)}'
          : null,
      ringPercent: ratio,
      ringColor: overflow ? AppColors.gasto : AppColors.gasto,
      leftStatLabel: 'Realizado',
      leftStatValue: formatUsd(realizado, decimals: false),
      rightStatLabel: overflow ? 'Excedido' : 'Falta',
      rightStatValue: overflow
          ? formatUsd(realizado - b.planned, decimals: false)
          : formatUsd(b.planned - realizado, decimals: false),
      metaLabel: 'Planificado',
      metaValue: formatUsd(b.planned, decimals: false),
      daysLabel: 'Prioridad',
      daysValue: b.priority.label,
      quickActions: const [],
      infoRows: [
        PlanDetailRow(label: 'País', value: b.country),
        if (b.description.isNotEmpty)
          PlanDetailRow(label: 'Descripción', value: b.description),
      ],
      historyTitle: 'Transacciones vinculadas',
      txns: state.txnsForBudgetItem(b),
      onEdit: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlanFormScreen.editBudget(b)),
      ),
      onDelete: () => _confirmDelete(
        context,
        state,
        title: '¿Eliminar planificación?',
        message:
            'Esto solo elimina el ítem de planificación. Las transacciones '
            'ya registradas NO se eliminan ni afectan tus KPIs — quedarán '
            'marcadas como "Pendente de planificación" para que puedas '
            'volver a organizarlas.',
        onConfirm: () => state.deleteBudget(b.id),
      ),
    );
  }
}

/// Layout comum da tela "Detalhes do Plano", parametrizado pelos 3 tipos
/// de plano — segue o mockup: header com voltar/badge, anel de progresso,
/// stats, ações rápidas, histórico e botões Editar/Excluir no final.
class _DetailScaffold extends StatelessWidget {
  final String title;
  final String badgeLabel;
  final Color badgeColor;
  final String? subtitle;
  final double ringPercent;
  final Color ringColor;
  final String leftStatLabel;
  final String leftStatValue;
  final String rightStatLabel;
  final String rightStatValue;
  final String metaLabel;
  final String metaValue;
  final String daysLabel;
  final String daysValue;
  final String? expiredWarning;
  final List<_QuickAction> quickActions;
  final List<Widget> infoRows;
  final String historyTitle;
  final List<Txn> txns;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DetailScaffold({
    required this.title,
    required this.badgeLabel,
    required this.badgeColor,
    this.subtitle,
    required this.ringPercent,
    required this.ringColor,
    required this.leftStatLabel,
    required this.leftStatValue,
    required this.rightStatLabel,
    required this.rightStatValue,
    required this.metaLabel,
    required this.metaValue,
    required this.daysLabel,
    required this.daysValue,
    this.expiredWarning,
    required this.quickActions,
    required this.infoRows,
    required this.historyTitle,
    required this.txns,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;
    final clamped = ringPercent.clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do plano'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          // ------- Título + badge + subtítulo -------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PlanBadge(label: badgeLabel, color: badgeColor),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12.5, color: mutedColor),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          if (expiredWarning != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      expiredWarning!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ------- Anel de progresso + Guardado/Falta -------
          Row(
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 108,
                      height: 108,
                      child: CircularProgressIndicator(
                        value: clamped,
                        strokeWidth: 10,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(ringColor),
                      ),
                    ),
                    Text(
                      '${(ringPercent * 100).clamp(0, 999).round()}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ringColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatLine(
                      label: leftStatLabel,
                      value: leftStatValue,
                      color: ringColor,
                    ),
                    const SizedBox(height: 10),
                    _StatLine(
                      label: rightStatLabel,
                      value: rightStatValue,
                      color: mutedColor ?? Colors.white70,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _StatLine(label: metaLabel, value: metaValue),
              ),
              Expanded(
                child: _StatLine(label: daysLabel, value: daysValue),
              ),
            ],
          ),

          if (quickActions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Acciones rápidas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final a in quickActions) ...[
                  Expanded(child: _QuickActionButton(action: a)),
                  if (a != quickActions.last) const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          ...infoRows,

          const SizedBox(height: AppSpacing.lg),
          Text(
            historyTitle,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: PlanTxnHistoryList(txns: txns, color: ringColor),
          ),

          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Editar plan'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 17,
                    color: AppColors.gasto,
                  ),
                  label: const Text(
                    'Eliminar plan',
                    style: TextStyle(color: AppColors.gasto),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatLine({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: action.color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            children: [
              Icon(action.icon, color: action.color, size: 20),
              const SizedBox(height: 5),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: action.color,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
