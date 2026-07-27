import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Opção de um [SegmentedFilterBar].
class FilterOption<T> {
  final T value;
  final String label;
  const FilterOption(this.value, this.label);
}

/// Barra de filtros unificada usada em Transações / Planificación /
/// Análisis. Regra de design inegociável: SEMPRE uma única linha, NUNCA
/// scroll horizontal, NUNCA uma segunda linha — as opções mais usadas
/// ficam neste controle segmentado (largura dividida igualmente, com o
/// texto se ajustando via [FittedBox] quando necessário); todos os demais
/// filtros vivem em um painel "avançado" único, acessível pelo botão de
/// funil ao lado (indicador visual quando há filtros avançados ativos).
class SegmentedFilterBar<T> extends StatelessWidget {
  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final VoidCallback? onAdvancedTap;
  final bool advancedActive;

  const SegmentedFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.onAdvancedTap,
    this.advancedActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                for (final opt in options)
                  Expanded(
                    child: _SegmentButton<T>(
                      label: opt.label,
                      selected: opt.value == selected,
                      color: primary,
                      onTap: () => onChanged(opt.value),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (onAdvancedTap != null) ...[
          const SizedBox(width: AppSpacing.sm),
          _AdvancedFilterButton(
            onTap: onAdvancedTap!,
            active: advancedActive,
          ),
        ],
      ],
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = selected
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.75);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdvancedFilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool active;
  const _AdvancedFilterButton({required this.onTap, required this.active});

  @override
  Widget build(BuildContext context) {
    final trackColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final color = active
        ? AppColors.inversion
        : Theme.of(context).iconTheme.color?.withValues(alpha: 0.75);
    return Material(
      color: active ? AppColors.inversion.withValues(alpha: 0.14) : trackColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(Icons.tune_rounded, size: 18, color: color),
              if (active)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.inversion,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painel padrão de "filtros avançados": modal bottom sheet com título,
/// botão "Limpar" e área de conteúdo customizável, seguido de um botão
/// "Aplicar filtros" de largura total. Usar SEMPRE este helper para que o
/// painel avançado tenha comportamento/visual idêntico em todas as telas.
Future<void> showAdvancedFiltersSheet(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext ctx, StateSetter setModalState) builder,
  VoidCallback? onClear,
  required VoidCallback onApply,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom: AppSpacing.lg + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(ctx).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (onClear != null)
                            TextButton(
                              onPressed: () {
                                onClear();
                                setModalState(() {});
                              },
                              child: const Text('Limpiar'),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      builder(ctx, setModalState),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            onApply();
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Aplicar filtros'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Título de seção usado dentro do painel de filtros avançados (ex.:
/// "Ámbito", "Categoría", "País"...).
class AdvancedFilterLabel extends StatelessWidget {
  final String text;
  const AdvancedFilterLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.md),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
