import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/period.dart';

/// Seletor de período estilo Google Analytics: um único botão exibindo o
/// intervalo atual (ex: "Diciembre 2025" ou "Ago – Dic 2025"), que ao ser
/// tocado abre uma folha com atalhos rápidos e um seletor de mês/año livre
/// para início e fim — sem jamais limitar os anos disponíveis.
///
/// [inline] remove o padding externo e o mainAxisSize.min interno, para que
/// o widget possa compartilhar uma linha com outros controles (ex.: botão
/// de "enfocar listado") sem ocupar uma linha inteira sozinho.
class PeriodSelector extends StatelessWidget {
  final bool inline;
  final bool compactHeader;
  final bool appBar;
  const PeriodSelector({
    super.key,
    this.inline = false,
    this.compactHeader = false,
    this.appBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final range = state.selectedRange;

    if (appBar) {
      // Versão reduzida horizontal, pensada para viver na AppBar (primeira
      // linha da tela), à esquerda do ícone de configurações — usada de
      // forma IDÊNTICA em todas as pestañas (Resumen/Transacciones/
      // Planificación/Análisis), já que a AppBar é compartilhada.
      return InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => _openPeriodSheet(context, state),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.darkBorder),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 13,
                color: AppColors.brandAmber,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 74),
                child: Text(
                  periodRangeShortLabel(range),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
            ],
          ),
        ),
      );
    }

    if (compactHeader) {
      // Versão estreita, pensada para compartilhar a mesma fila dos 3
      // cards de KPI (Ingresos/Gastos/Inversiones), do lado direito.
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openPeriodSheet(context, state),
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.darkBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 14,
                color: AppColors.brandAmber,
              ),
              const SizedBox(height: 2),
              Text(
                periodRangeShortLabel(range),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 12),
            ],
          ),
        ),
      );
    }

    final button = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openPeriodSheet(context, state),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.darkBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: inline ? MainAxisSize.max : MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: AppColors.brandAmber,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                periodRangeLabel(range),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );

    if (inline) return button;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: button,
    );
  }

  void _openPeriodSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PeriodSheet(state: state),
    );
  }
}

class _PeriodSheet extends StatefulWidget {
  final AppState state;
  const _PeriodSheet({required this.state});

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late YearMonth _customStart;
  late YearMonth _customEnd;
  bool _showCustom = false;

  @override
  void initState() {
    super.initState();
    _customStart = widget.state.selectedRange.start;
    _customEnd = widget.state.selectedRange.end;
  }

  void _apply(PeriodRange range) {
    widget.state.setSelectedRange(range);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final now = YearMonth.fromDate(DateTime.now());
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleccionar período',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _ShortcutChip(
                  label: 'Este mes',
                  onTap: () => _apply(PeriodRange.singleMonth(now)),
                ),
                _ShortcutChip(
                  label: 'Mes pasado',
                  onTap: () => _apply(PeriodRange.singleMonth(now.previous())),
                ),
                _ShortcutChip(
                  label: 'Últimos 3 meses',
                  onTap: () => _apply(PeriodRange.lastNMonths(3)),
                ),
                _ShortcutChip(
                  label: 'Últimos 6 meses',
                  onTap: () => _apply(PeriodRange.lastNMonths(6)),
                ),
                _ShortcutChip(
                  label: 'Últimos 12 meses',
                  onTap: () => _apply(PeriodRange.lastNMonths(12)),
                ),
                _ShortcutChip(
                  label: 'Personalizado',
                  selected: _showCustom,
                  onTap: () => setState(() => _showCustom = !_showCustom),
                ),
              ],
            ),
            if (_showCustom) ...[
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Text('Desde', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              _MonthYearPicker(
                value: _customStart,
                onChanged: (ym) => setState(() => _customStart = ym),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Hasta', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              _MonthYearPicker(
                value: _customEnd,
                onChanged: (ym) => setState(() => _customEnd = ym),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      _apply(PeriodRange(_customStart, _customEnd)),
                  child: const Text('Aplicar período'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool selected;
  const _ShortcutChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected
          ? AppColors.brandAmber.withValues(alpha: 0.28)
          : null,
      labelStyle: TextStyle(
        color: selected ? AppColors.brandAmber : null,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }
}

/// Seletor livre de mês/ano — o campo de año é um TextFormField, portanto
/// nunca há um limite artificial de anos disponíveis (o usuário pode
/// digitar qualquer ano, passado o futuro).
class _MonthYearPicker extends StatefulWidget {
  final YearMonth value;
  final ValueChanged<YearMonth> onChanged;
  const _MonthYearPicker({required this.value, required this.onChanged});

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late TextEditingController _yearCtrl;
  final FocusNode _yearFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _yearCtrl = TextEditingController(text: widget.value.year.toString());
  }

  @override
  void didUpdateWidget(covariant _MonthYearPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // BUGFIX: antes este método reescrevia `_yearCtrl.text` sempre que
    // `widget.value.year` mudava — o que inclui as mudanças que O PRÓPRIO
    // campo provocou (já que cada tecla digitada chama `onChanged` →
    // `widget.onChanged` → `setState` no pai → rebuild deste widget com um
    // novo `value.year` idêntico ao texto recém-digitado). Sobrescrever
    // `.text` sempre reseta a seleção/cursor para o fim, e ao fazer isso a
    // cada keystroke (especialmente no Flutter Web) o texto digitado
    // "se apagava" porque o controller era resetado no meio da composição.
    // Correção: só ressincronizar quando (a) o texto realmente mudou E
    // (b) o campo não está em foco (ou seja, a mudança veio de uma fonte
    // externa, como trocar de atalho "Desde"/"Hasta", não da digitação).
    final newText = widget.value.year.toString();
    if (_yearCtrl.text != newText && !_yearFocus.hasFocus) {
      _yearCtrl.text = newText;
    }
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _yearFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            initialValue: widget.value.month,
            decoration: const InputDecoration(labelText: 'Mes'),
            items: List.generate(12, (i) => i + 1)
                .map(
                  (m) =>
                      DropdownMenuItem(value: m, child: Text(monthNamesEs[m])),
                )
                .toList(),
            onChanged: (m) {
              if (m != null) {
                widget.onChanged(YearMonth(widget.value.year, m));
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _yearCtrl,
            focusNode: _yearFocus,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Año'),
            onChanged: (v) {
              final y = int.tryParse(v);
              if (y != null && y > 0) {
                widget.onChanged(YearMonth(y, widget.value.month));
              }
            },
          ),
        ),
      ],
    );
  }
}
