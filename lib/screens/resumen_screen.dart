import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/budget_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class ResumenScreen extends StatelessWidget {
  const ResumenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final balance = state.balance;
    final upcoming = state.upcomingDue();
    final goals = state.goals;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        _DeficitRolloverBanner(),
        balance >= 0
            ? _SurplusCard(amount: balance)
            : _DeficitCard(amount: -balance),
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(
          title: 'Próximos pagos pendientes',
          trailing: Text(
            '${upcoming.length} pendiente(s)',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
        if (upcoming.isEmpty)
          SectionCard(
            child: Row(
              children: const [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.ingreso,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('No hay pagos venciendo en los próximos 7 días.'),
                ),
              ],
            ),
          )
        else
          ...upcoming.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _UpcomingTile(item: b),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(title: 'Objetivos de inversión'),
        if (goals.isEmpty)
          const SectionCard(
            child: Text('Aún no has creado objetivos de inversión.'),
          )
        else
          ...goals.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _GoalSummaryTile(goal: g),
            ),
          ),
      ],
    );
  }
}

class _DeficitRolloverBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rollovers = state.txnsForSelectedPeriods
        .where((t) => t.isDeficitRollover)
        .toList();
    if (rollovers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        children: rollovers
            .map(
              (t) => Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                      Icons.info_outline_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${t.description} (${formatUsd(t.amount)})',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SurplusCard extends StatelessWidget {
  final double amount;
  const _SurplusCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: AppColors.ingreso),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Excedente de ${formatUsd(amount)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ingreso,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tienes ${formatUsd(amount)} por encima de tus gastos planificados. Opciones:',
            style: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _ActionChipButton(
                label: 'Reinvertir ${formatUsd(amount, decimals: false)}',
                icon: Icons.savings_rounded,
                primary: true,
              ),
              _ActionChipButton(
                label: 'Aumentar fondo de emergencia',
                icon: Icons.shield_outlined,
              ),
              _ActionChipButton(
                label: 'Reducir deudas pendientes',
                icon: Icons.account_balance_outlined,
              ),
              _ActionChipButton(
                label: 'Guardar para objetivo',
                icon: Icons.flag_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeficitCard extends StatelessWidget {
  final double amount;
  const _DeficitCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.gasto),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Déficit de ${formatUsd(amount)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gasto,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Estás ${formatUsd(amount)} por encima de tu ingreso. Acciones recomendadas:',
            style: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _ActionChipButton(
                label: 'Reducir ocio a \$0',
                icon: Icons.pause_circle_outline_rounded,
                primary: true,
              ),
              _ActionChipButton(
                label:
                    'Postergar inversión: ${formatUsd(amount, decimals: false)}',
                icon: Icons.schedule_rounded,
              ),
              _ActionChipButton(
                label: 'Reducir educación y otros',
                icon: Icons.trending_down_rounded,
              ),
              _ActionChipButton(
                label: 'Usar fondo de emergencia',
                icon: Icons.shield_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  const _ActionChipButton({
    required this.label,
    required this.icon,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: primary ? Colors.black : null),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          color: primary ? Colors.black : null,
          fontWeight: primary ? FontWeight.w600 : null,
        ),
      ),
      backgroundColor: primary ? AppColors.brandAmber : null,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sugerencia registrada: "$label"')),
        );
      },
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final BudgetItem item;
  const _UpcomingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final cat = state.expenseCategories.firstWhere(
      (c) => c.name == item.category,
      orElse: () => state.expenseCategories.isNotEmpty
          ? state.expenseCategories.first
          : throw StateError('sin categorías'),
    );
    final daysLeft = item.dueDate!.difference(DateTime.now()).inDays;
    final urgent = daysLeft <= 2;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgent
              ? AppColors.alertaAlta.withValues(alpha: 0.5)
              : (Theme.of(context).dividerTheme.color ?? Colors.transparent),
          width: urgent ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          CategoryIcon(iconKey: cat.icon, color: AppColors.gasto),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.category} · ${item.subcategory}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vence ${formatFullDate(item.dueDate!)} · ${daysLeft <= 0 ? "hoy" : "en $daysLeft día(s)"}',
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
                formatUsd(item.planned),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              PriorityBadge(priority: item.priority),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalSummaryTile extends StatelessWidget {
  final InvestmentGoal goal;
  const _GoalSummaryTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${(goal.progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.inversion,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBarWithOverflow(
            value: goal.progress,
            color: AppColors.inversion,
          ),
          const SizedBox(height: 6),
          Text(
            '${formatUsd(goal.currentAmount, decimals: false)} de ${formatUsd(goal.targetAmount, decimals: false)}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}
