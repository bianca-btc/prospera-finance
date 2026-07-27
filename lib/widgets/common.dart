import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/icon_map.dart';

/// Badge de status (Pagado/Pendiente).
class StatusBadge extends StatelessWidget {
  final TxStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isPaid = status == TxStatus.pagado;
    final color = isPaid ? AppColors.ingreso : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Badge de prioridade (Alta/Media/Baja).
class PriorityBadge extends StatelessWidget {
  final Priority priority;
  const PriorityBadge({super.key, required this.priority});

  Color _color() {
    switch (priority) {
      case Priority.alta:
        return AppColors.alertaAlta;
      case Priority.media:
        return AppColors.alertaMedia;
      case Priority.baja:
        return AppColors.alertaBaja;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Ícone circular colorido representando uma categoria.
class CategoryIcon extends StatelessWidget {
  final String iconKey;
  final Color color;
  final double size;
  const CategoryIcon({
    super.key,
    required this.iconKey,
    required this.color,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(iconFor(iconKey), color: color, size: size * 0.52),
    );
  }
}

/// Cabecera estándar de pantalla (Design System): ícono + título principal
/// arriba, y una frase explicativa corta debajo describiendo el propósito
/// de la pestaña. Usado de forma idéntica en Transacciones, Planificación
/// y Análisis para garantizar coherencia visual entre las tres.
class ScreenHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const ScreenHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
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

/// Título de seção padrão usado em várias abas.
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Card container padrão com bordas sutis, usado em várias telas.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
        ),
      ),
      child: child,
    );
  }
}

/// Barra de progresso customizada (linear) com cor e overflow.
class ProgressBarWithOverflow extends StatelessWidget {
  final double value; // 0..N (pode passar de 1 para indicar overflow)
  final Color color;
  final double height;

  const ProgressBarWithOverflow({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, 1.0).toDouble();
    final overflow = value > 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(
            height: height,
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          FractionallySizedBox(
            widthFactor: clamped,
            child: Container(
              height: height,
              color: overflow ? Colors.red.shade700 : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastilla de status compacta, reutilizada en tarjetas de Planificación y
/// en la pantalla de Detalles del Plan (p.ej. "Em dia"/"Atenção"/"Cubierto").
class PlanBadge extends StatelessWidget {
  final String label;
  final Color color;
  const PlanBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Fila etiqueta/valor reutilizada en tarjetas expandidas y en la pantalla
/// de Detalles del Plan.
class PlanDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const PlanDetailRow({super.key, required this.label, required this.value});

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

/// Lista de histórico de movimentações vinculadas a um plano (Gasto/Deuda/
/// Objetivo) — reutilizada tanto nas tarjetas de Planificación quanto na
/// pantalla dedicada "Detalhes do Plano".
class PlanTxnHistoryList extends StatelessWidget {
  final List<Txn> txns;
  final Color color;
  const PlanTxnHistoryList({
    super.key,
    required this.txns,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (txns.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'Ninguna transacción registrada todavía.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      );
    }
    return Column(
      children: txns.map((t) {
        final isNegative = !t.isEffectivelyInflow;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 9),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.description.isNotEmpty
                          ? t.description
                          : t.movementTypeLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      formatFullDate(t.date),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isNegative ? '-' : '+'}${formatUsd(t.amount, decimals: false)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isNegative ? color : AppColors.ingreso,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
