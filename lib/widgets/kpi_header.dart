import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'common.dart';
import 'period_selector.dart';

/// Header de KPIs, compacto: Ingresos, Gastos e Inversiones SIEMPRE en la
/// misma fila; Saldo aparece debajo en una fila más pequeña, que indica
/// visualmente si es positivo o negativo. Soporta un modo [compact] que
/// reduce aún más el header (usado cuando el usuario quiere enfocarse en
/// los listados de las pestañas).
class KpiHeader extends StatelessWidget {
  final VoidCallback? onGastosTap;
  final VoidCallback? onInversionesTap;
  final bool compact;

  const KpiHeader({
    super.key,
    this.onGastosTap,
    this.onInversionesTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Los 3 KPIs principales representan ESTADOS del dinero (histórico
    // completo, sin filtrar por período) para que la ecuación fundamental
    // "Ingreso disponible + Gastos + Inversiones = Total Ingresos" se
    // cumpla SIEMPRE, sin importar qué período tenga seleccionado el
    // usuario en el filtro. Así, un aporte o rescate hecho en cualquier
    // mes siempre se refleja correctamente en el KPI de Ingreso disponible.
    final ingresos = state.ingresoDisponible;
    final gastos = state.totalGastosHistorico;
    final inversiones = state.inversionesActuales;

    // El "flujo neto del período" (fila inferior) sí respeta el filtro de
    // período seleccionado — es información complementaria sobre cómo se
    // movió el dinero EN ESE período específico, distinta del estado
    // acumulado (Ingreso disponible) mostrado arriba.
    final balance = state.balance;

    // Las barras de progreso comparan lo EJECUTADO EN EL PERÍODO vs. lo
    // PLANIFICADO EN EL PERÍODO — a propósito distinto del número
    // principal de la tarjeta (que es el estado histórico acumulado), para
    // que el usuario pueda seguir viendo "cuánto llevo gastado este mes".
    final gastosPeriodo = state.totalGastosYDeudas;
    final inversionesPeriodo = state.totalInversiones;
    final plannedGastos = state.plannedGastosSelected;
    final gastosRatio = state.gastosExecutedRatio;

    final plannedInversion = state.investmentGoalPlannedSelected;
    final inversionRatio = state.investmentExecutedRatio;
    final metaConcluida = state.investmentGoalCompleted;
    final metaSuperada = state.investmentGoalExceeded;

    final balanceColor = balance >= 0 ? AppColors.ingreso : AppColors.gasto;

    if (compact) {
      // Modo compacto: una sola fila resumida (usada al "enfocar listados").
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 6,
        ),
        child: Row(
          children: [
            Expanded(
              child: _CompactStat(
                label: 'Disponible',
                value: formatUsd(ingresos, decimals: false),
                color: AppColors.ingreso,
              ),
            ),
            Expanded(
              child: _CompactStat(
                label: 'Gastos',
                value: formatUsd(gastos, decimals: false),
                color: AppColors.gasto,
              ),
            ),
            Expanded(
              child: _CompactStat(
                label: 'Inversiones',
                value: formatUsd(inversiones, decimals: false),
                color: AppColors.inversion,
              ),
            ),
            Expanded(
              child: _CompactStat(
                label: 'Flujo período',
                value: formatUsdSigned(balance),
                color: balanceColor,
              ),
            ),
            const SizedBox(width: 6),
            const PeriodSelector(compactHeader: true),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          // Ingresos, Gastos e Inversiones SIEMPRE en la misma fila, con el
          // selector de período compartiendo esa misma línea (lado derecho)
          // para no ocupar una fila entera solo para el filtro.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _KpiCard(
                    label: 'Ingreso disponible',
                    value: formatUsd(ingresos, decimals: false),
                    color: AppColors.ingreso,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _KpiCard(
                    label: 'Gastos',
                    value: formatUsd(gastos, decimals: false),
                    color: AppColors.gasto,
                    onTap: onGastosTap,
                    progress: plannedGastos > 0
                        ? _KpiProgress(
                            // La barra de Gastos siempre es roja
                            // (AppColors.gasto), sin importar el nivel de
                            // progreso alcanzado.
                            ratio: gastosRatio,
                            color: AppColors.gasto,
                            caption:
                                '${formatUsd(gastosPeriodo, decimals: false)}/${formatUsd(plannedGastos, decimals: false)}',
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _KpiCard(
                    label: 'Inversiones',
                    value: formatUsd(inversiones, decimals: false),
                    color: AppColors.inversion,
                    onTap: onInversionesTap,
                    progress: plannedInversion > 0
                        ? _KpiProgress(
                            // La barra de Inversiones siempre es azul
                            // (AppColors.inversion), sin importar si la
                            // meta fue alcanzada o superada.
                            ratio: inversionRatio,
                            color: AppColors.inversion,
                            caption: metaSuperada
                                ? 'Meta superada'
                                : metaConcluida
                                    ? 'Meta concluída'
                                    : '${formatUsd(inversionesPeriodo, decimals: false)}/${formatUsd(plannedInversion, decimals: false)}',
                            captionBold: metaConcluida || metaSuperada,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                const PeriodSelector(compactHeader: true),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Flujo neto del período seleccionado: fila propia, con estilo
          // visualmente distinto (diagonal / pastilla) de los 3 KPIs de
          // arriba (que son ESTADOS acumulados). Esta fila sí respeta el
          // filtro de período — muestra cuánto entró/salió en ese período,
          // sin alterar la lectura del Ingreso disponible acumulado.
          _SaldoRow(balance: balance, color: balanceColor),
        ],
      ),
    );
  }
}

/// Fila compacta y claramente diferenciada para el Saldo: a diferencia de
/// los 3 cards de KPI (rectángulos con etiqueta arriba y valor abajo), acá
/// usamos un ícono circular "de estado" a la izquierda seguido del NÚMERO
/// (también a la izquierda), y la etiqueta "Saldo" pasa a un segundo plano
/// a la derecha — reforzando que se trata de un resultado (diferencia),
/// no de una métrica más de la misma familia.
class _SaldoRow extends StatelessWidget {
  final double balance;
  final Color color;
  const _SaldoRow({required this.balance, required this.color});

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        // Gradiente sutil (en vez del fondo plano de los KPI cards) para
        // diferenciar visualmente esta fila como "resultado" y no como un
        // cuarto KPI más.
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(
              isPositive
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 15,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatUsdSigned(balance),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Text(
            isPositive
                ? 'Flujo positivo (período)'
                : 'Flujo negativo (período)',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estadística compacta (modo colapsado): solo etiqueta + valor.
class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CompactStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Dados da barra de progresso exibida dentro de um [_KpiCard].
class _KpiProgress {
  final double ratio; // 0..N (pode passar de 1 = excesso)
  final Color color;
  final String caption;
  final bool captionBold;

  const _KpiProgress({
    required this.ratio,
    required this.color,
    required this.caption,
    this.captionBold = false,
  });
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool emphasis;
  final VoidCallback? onTap;
  final _KpiProgress? progress;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    this.emphasis = false,
    this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: emphasis
            ? color.withValues(alpha: 0.10)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: emphasis
              ? color.withValues(alpha: 0.35)
              : (Theme.of(context).dividerTheme.color ?? Colors.transparent),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 5),
            ProgressBarWithOverflow(
              value: progress!.ratio,
              color: progress!.color,
              height: 5,
            ),
            const SizedBox(height: 3),
            Text(
              progress!.caption,
              style: TextStyle(
                fontSize: 9,
                fontWeight: progress!.captionBold
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: progress!.captionBold
                    ? progress!.color
                    : Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.65),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
