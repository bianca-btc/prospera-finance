import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Header com 4 KPIs fixos: Ingresos, Gastos+Deudas, Inversiones, Balance.
/// Quando múltiplos meses estão selecionados, mostra total acumulado + média mensal.
class KpiHeader extends StatelessWidget {
  const KpiHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final periods = state.selectedPeriods;
    final n = periods.length;

    final ingresos = state.totalIngresos;
    final gastos = state.totalGastosYDeudas;
    final inversiones = state.totalInversiones;
    final balance = state.balance;
    final plannedGastos = state.plannedTotalSelected;
    final metaInversion = state.goalsTargetTotal;
    final investedTotal = state.goalsCurrentTotal;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;
          final children = [
            _KpiCard(
              label: 'Ingresos',
              value: formatUsd(ingresos),
              sub: n > 1 ? 'Prom. ${formatUsd(ingresos / n)}/mes' : null,
              color: AppColors.ingreso,
              icon: Icons.arrow_downward_rounded,
            ),
            _KpiCard(
              label: 'Gastos + Deudas',
              value: formatUsd(gastos),
              sub:
                  '${formatUsd(gastos, decimals: false)} de ${formatUsd(plannedGastos, decimals: false)} planificado',
              color: AppColors.gasto,
              icon: Icons.arrow_upward_rounded,
            ),
            _KpiCard(
              label: 'Inversiones',
              value: formatUsd(inversiones),
              sub:
                  '${formatUsd(investedTotal, decimals: false)} de ${formatUsd(metaInversion, decimals: false)} meta',
              color: AppColors.inversion,
              icon: Icons.trending_up_rounded,
            ),
            _KpiCard(
              label: 'Balance',
              value: formatUsdSigned(balance),
              sub: balance >= 0 ? 'Excedente' : 'Déficit',
              color: balance >= 0 ? AppColors.ingreso : AppColors.gasto,
              icon: balance >= 0
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
            ),
          ];

          if (isNarrow) {
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.5,
              children: children,
            );
          }
          return Row(
            children: children
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: c,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.value,
    this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: TextStyle(
                fontSize: 10.5,
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.55),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
