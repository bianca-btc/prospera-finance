import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_theme.dart';
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
