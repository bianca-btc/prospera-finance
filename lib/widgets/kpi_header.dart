import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'common.dart';
import 'period_selector.dart';

/// Header de KPIs, dividido en dos categorías claramente distintas:
///
/// 1) SALDO DISPONIBLE -- indicador principal de SITUACIÓN FINANCIERA
///    ACTUAL (histórico completo, jamás depende del período seleccionado
///    ni de filtros avanzados). Se muestra arriba, con un diseño
///    visualmente distinto (tarjeta destacada) de los demás 4 KPIs.
///
/// 2) Grid 2x2 con dos filas:
///    - Fila 1 (INDICADORES DE FLUJO -- SÍ dependen del período
///      seleccionado): Ingresos (verde) | Gastos (rojo).
///    - Fila 2 (INDICADORES DE SITUACIÓN -- NO dependen del período):
///      Objetivos (azul) | Deudas (amarillo, saldo pendiente actual).
///
/// Ningún filtro avanzado afecta estos valores en ningún caso -- solo
/// filtran listas/gráficos/análisis detallados en sus propias pantallas.
/// Soporta un modo [compact] que reduce aun mas el header (usado cuando el
/// usuario quiere enfocarse en los listados de las pestanas).
class KpiHeader extends StatelessWidget {
  final VoidCallback? onGastosTap;
  final VoidCallback? onInversionesTap;
  final VoidCallback? onDeudasTap;
  final bool compact;

  const KpiHeader({
    super.key,
    this.onGastosTap,
    this.onInversionesTap,
    this.onDeudasTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // -------- Situación financiera actual (NO dependen del período) -----
    final disponible = state.ingresoDisponible;
    final objetivos = state.objetivosActuales;
    final deudas = state.totalDeudaPendiente;

    // -------- Flujo del período (SÍ dependen del filtro global) --------
    final ingresos = state.totalIngresos;
    final gastos = state.totalGastosPurosSelected;

    // Las barras de progreso comparan lo EJECUTADO EN EL PERIODO vs. lo
    // PLANIFICADO EN EL PERIODO seleccionado -- coherente con que el
    // planeamiento/progreso siempre siga al filtro global de período.
    final plannedGastos = state.plannedGastosPurosSelected;
    final gastosRatio = state.gastosPurosExecutedRatio;

    // Objetivos y Deudas son KPIs de SITUACIÓN FINANCIERA: sus barras de
    // progreso son ABSOLUTAS (pagado/aportado total vs. meta/deuda total),
    // nunca dependen del período seleccionado ni de filtros avanzados.
    final plannedDeuda = state.debtsTotalAmountAbs;
    final deudaRatio = state.debtsProgressRatioAbs;

    final plannedInversion = state.goalsTargetTotalAbs;
    final inversionRatio = state.goalsProgressRatioAbs;
    final metaConcluida = state.goalsCompletedAbs;
    final metaSuperada = state.goalsExceededAbs;

    if (compact) {
      // Modo compacto: header reducido (usado al "enfocar listados").
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Spacer(),
                const PeriodSelector(compactHeader: true),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _CompactStat(
                    label: 'Disponible',
                    value: formatUsd(disponible, decimals: false),
                    color: disponible >= 0
                        ? AppColors.ingreso
                        : AppColors.gasto,
                  ),
                ),
                Expanded(
                  child: _CompactStat(
                    label: 'Ingresos',
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
                    label: 'Objetivos',
                    value: formatUsd(objetivos, decimals: false),
                    color: AppColors.inversion,
                  ),
                ),
                Expanded(
                  child: _CompactStat(
                    label: 'Deudas',
                    value: formatUsd(deudas, decimals: false),
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Spacer(), const PeriodSelector(inline: true)]),
          const SizedBox(height: 8),
          // Bloque 1: Saldo Disponible -- indicador principal, visualmente
          // destacado y distinto de los demás 4 KPIs. Nunca depende del
          // período ni de filtros avanzados.
          _SaldoDisponibleCard(value: disponible),
          const SizedBox(height: 10),
          // Bloque 2: grid 2x2 SIN scroll horizontal.
          // Fila 1 (FLUJO del período): Ingresos | Gastos.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.trending_up_rounded,
                    label: 'Ingresos',
                    value: formatUsd(ingresos, decimals: false),
                    color: AppColors.ingreso,
                    subtitle: 'En el período',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.trending_down_rounded,
                    label: 'Gastos',
                    value: formatUsd(gastos, decimals: false),
                    limitValue: plannedGastos > 0
                        ? formatUsd(plannedGastos, decimals: false)
                        : null,
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
                                '${(gastosRatio * 100).clamp(0, 999).round()}% del plan',
                          )
                        : null,
                    subtitle: plannedGastos > 0 ? null : 'En el período',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Fila 2 (SITUACIÓN financiera): Objetivos | Deudas.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.track_changes_rounded,
                    label: 'Objetivos',
                    value: formatUsd(objetivos, decimals: false),
                    limitValue: plannedInversion > 0
                        ? formatUsd(plannedInversion, decimals: false)
                        : null,
                    color: AppColors.inversion,
                    onTap: onInversionesTap,
                    progress: plannedInversion > 0
                        ? _KpiProgress(
                            // La barra de Objetivos siempre es azul
                            // (AppColors.inversion), sin importar si la
                            // meta fue alcanzada o superada.
                            ratio: inversionRatio,
                            color: AppColors.inversion,
                            caption: metaSuperada
                                ? 'Meta superada'
                                : metaConcluida
                                ? 'Meta concluida'
                                : '${(inversionRatio * 100).clamp(0, 999).round()}% de la meta',
                            captionBold: metaConcluida || metaSuperada,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.credit_card_rounded,
                    label: 'Deudas',
                    value: formatUsd(deudas, decimals: false),
                    limitValue: plannedDeuda > 0
                        ? formatUsd(plannedDeuda, decimals: false)
                        : null,
                    color: AppColors.warning,
                    onTap: onDeudasTap,
                    progress: plannedDeuda > 0
                        ? _KpiProgress(
                            // La barra de Deudas siempre es amarilla
                            // (AppColors.warning), sin importar el nivel
                            // de progreso alcanzado.
                            ratio: deudaRatio,
                            color: AppColors.warning,
                            caption:
                                '${(deudaRatio * 100).clamp(0, 999).round()}% pagado',
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta destacada de Saldo Disponible -- indicador principal de la
/// pantalla Resumen. Diseño intencionalmente distinto de los 4 KPIs de
/// abajo (más grande, ancho completo, badge de estado) para reforzar que
/// representa la situación financiera actual REAL del usuario, sin
/// importar el período o filtro seleccionado.
class _SaldoDisponibleCard extends StatelessWidget {
  final double value;
  const _SaldoDisponibleCard({required this.value});

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    final color = positive ? AppColors.ingreso : AppColors.gasto;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.3),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.22),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Saldo disponible',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatUsd(value, decimals: false),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              positive ? 'Positivo' : 'Negativo',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estadistica compacta (modo colapsado): solo etiqueta + valor.
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
  final IconData icon;
  final String label;
  final String value;
  final String? limitValue;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  final _KpiProgress? progress;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.limitValue,
    this.subtitle,
    required this.color,
    this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withValues(alpha: 0.62);

    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.22),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 15, color: mutedColor),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (limitValue != null)
                  Text(
                    ' / $limitValue',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: mutedColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 7),
            ProgressBarWithOverflow(
              value: progress!.ratio,
              color: progress!.color,
              height: 5,
            ),
            const SizedBox(height: 4),
            Text(
              progress!.caption,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: progress!.captionBold
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: progress!.captionBold ? progress!.color : mutedColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ] else if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: mutedColor,
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
