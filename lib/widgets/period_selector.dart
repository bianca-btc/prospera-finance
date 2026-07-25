import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/period.dart';

/// Seletor de período com múltipla escolha (chips), suportando qualquer
/// mês/ano — inclusive anos futuros — para uso contínuo do app.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final periods = state.availablePeriods;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: periods.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == periods.length) {
            return _AddPeriodChip(onPick: (ym) => state.togglePeriod(ym));
          }
          final ym = periods[index];
          final selected = state.selectedPeriods.contains(ym);
          return ChoiceChip(
            label: Text(monthShortLabel(ym)),
            selected: selected,
            onSelected: (_) => state.togglePeriod(ym),
            selectedColor: AppColors.brandAmber.withValues(alpha: 0.28),
            labelStyle: TextStyle(
              color: selected ? AppColors.brandAmber : null,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          );
        },
      ),
    );
  }
}

class _AddPeriodChip extends StatelessWidget {
  final void Function(YearMonth) onPick;
  const _AddPeriodChip({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.calendar_month_rounded, size: 16),
      label: const Text('Otro mes'),
      onPressed: () async {
        final now = DateTime.now();
        int year = now.year;
        int month = now.month;
        await showModalBottomSheet(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setSt) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seleccionar mes/año',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: month,
                              decoration: const InputDecoration(
                                labelText: 'Mes',
                              ),
                              items: List.generate(12, (i) => i + 1)
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(monthNamesEs[m]),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setSt(() => month = v!),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: year,
                              decoration: const InputDecoration(
                                labelText: 'Año',
                              ),
                              items: List.generate(9, (i) => now.year - 2 + i)
                                  .map(
                                    (y) => DropdownMenuItem(
                                      value: y,
                                      child: Text('$y'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setSt(() => year = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            onPick(YearMonth(year, month));
                            Navigator.pop(ctx);
                          },
                          child: const Text('Agregar período'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
