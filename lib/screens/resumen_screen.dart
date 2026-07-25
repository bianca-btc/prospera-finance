import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/goal.dart';
import '../models/insight.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/icon_map.dart';
import '../widgets/common.dart';

/// Pantalla Resumen — rediseñada según el principio "Menos información,
/// más claridad": muestra únicamente lo esencial para responder "¿Cómo
/// está mi situación financiera?" en pocos segundos. Los KPIs grandes
/// (Saldo/Ingresos/Gastos/Inversiones) ya se muestran en el header fijo
/// arriba, así que aquí solo agregamos: Resumo Inteligente, Principales
/// gastos, Próximos vencimientos y Objetivos — y solo los cards que el
/// usuario eligió mostrar (personalización).
class ResumenScreen extends StatelessWidget {
  const ResumenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final visible = state.visibleCards;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        if (visible.contains('resumo_inteligente'))
          const _ResumoInteligenteSection(),
        if (visible.contains('principales_gastos'))
          const _PrincipalesGastosSection(),
        if (visible.contains('proximos_vencimientos'))
          const _ProximosVencimientosSection(),
        if (visible.contains('objetivos')) const _ObjetivosSection(),
      ],
    );
  }
}

/// "Resumo Inteligente" — el corazón de la propuesta: sustituye números
/// y tablas por frases interpretativas generadas por el InsightsEngine.
class _ResumoInteligenteSection extends StatelessWidget {
  const _ResumoInteligenteSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final insights = state.generateInsights();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Resumen inteligente'),
          if (insights.isEmpty)
            const SectionCard(
              child: Text(
                'Todo está en orden. Sigue registrando tus movimientos para recibir recomendaciones personalizadas.',
              ),
            )
          else
            ...insights.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _InsightCard(insight: i),
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Insight insight;
  const _InsightCard({required this.insight});

  Color _colorFor(InsightTone tone) {
    switch (tone) {
      case InsightTone.positivo:
        return AppColors.ingreso;
      case InsightTone.alerta:
        return AppColors.warning;
      case InsightTone.peligro:
        return AppColors.gasto;
      case InsightTone.neutro:
        return AppColors.inversion;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(insight.tone);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconFor(insight.iconKey), color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              insight.text,
              style: const TextStyle(fontSize: 13.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// "¿Dónde estoy gastando más?" respondida directamente en el Resumen,
/// mostrando solo el top 3 de categorías — sin gráficos, sin tablas.
class _PrincipalesGastosSection extends StatelessWidget {
  const _PrincipalesGastosSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final txns = state.txnsForSelectedPeriods
        .where((t) => t.type == TxType.gasto)
        .toList();

    final Map<String, double> byCategory = {};
    for (final t in txns) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).toList();
    final total = byCategory.values.fold(0.0, (s, v) => s + v);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Principales gastos'),
          if (top3.isEmpty)
            const SectionCard(
              child: Text('Aún no registraste gastos en este período.'),
            )
          else
            SectionCard(
              child: Column(
                children: top3.map((e) {
                  final cat = state.expenseCategories.firstWhere(
                    (c) => c.name == e.key,
                    orElse: () => state.expenseCategories.isNotEmpty
                        ? state.expenseCategories.first
                        : throw StateError('sin categorías'),
                  );
                  final pct = total > 0 ? (e.value / total * 100) : 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        CategoryIcon(
                          iconKey: cat.icon,
                          color: AppColors.gasto,
                          size: 32,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatUsd(e.value, decimals: false),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// "¿Qué debo pagar primero?" — próximos vencimientos, ordenados.
class _ProximosVencimientosSection extends StatelessWidget {
  const _ProximosVencimientosSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final upcoming = state.upcomingDue();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Próximos vencimientos'),
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
                    child: Text(
                      'No hay pagos venciendo en los próximos 7 días.',
                    ),
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
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final dynamic item; // BudgetItem
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
          Text(
            formatUsd(item.planned, decimals: false),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// "¿Cuánto puedo invertir?" — objetivos financieros con su progreso.
class _ObjetivosSection extends StatelessWidget {
  const _ObjetivosSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goals = state.goals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Objetivos financieros'),
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
