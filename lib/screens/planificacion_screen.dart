import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/budget_item.dart';
import '../models/debt.dart';
import '../models/enums.dart';
import '../models/goal.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/period.dart';
import '../widgets/common.dart';
import '../widgets/filter_bar.dart';
import '../widgets/period_selector.dart';
import 'plan_detail_screen.dart';
import 'plan_form_screen.dart';

/// Filtro superior estilo "chips" (Todos/Gastos/Dívidas/Objetivos) — no
/// oculta secciones distintas, solo decide cuáles de las 3 categorías de
/// planificación se muestran en la lista.
enum _PlanFilter { todos, gastos, deudas, objetivos }

class PlanificacionScreen extends StatefulWidget {
  const PlanificacionScreen({super.key});

  @override
  State<PlanificacionScreen> createState() => _PlanificacionScreenState();
}

class _PlanificacionScreenState extends State<PlanificacionScreen> {
  // Selección múltiple: solo se aplica a los planes de Gasto normal (los
  // de Deuda/Objetivo se administran por su propia tarjeta especial, con
  // sus propias acciones de pago/aporte, y no tiene sentido replicarlos ni
  // excluirlos en masa desde aquí).
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  _PlanFilter _filter = _PlanFilter.todos;

  // ------- Filtros avançados (categoria/subcategoria/país/status) -------
  String? _advCategory;
  String? _advSubcategory;
  String? _advCountry;
  TxStatus? _advStatus;

  bool get _hasAdvancedFilters =>
      _advCategory != null ||
      _advSubcategory != null ||
      _advCountry != null ||
      _advStatus != null;

  void _clearAdvancedFilters() {
    _advCategory = null;
    _advSubcategory = null;
    _advCountry = null;
    _advStatus = null;
  }

  bool _matchesAdvanced({
    String? category,
    String? subcategory,
    String? country,
    TxStatus? status,
  }) {
    if (_advCategory != null && category != _advCategory) return false;
    if (_advSubcategory != null && subcategory != _advSubcategory) {
      return false;
    }
    if (_advCountry != null && country != _advCountry) return false;
    if (_advStatus != null && status != _advStatus) return false;
    return true;
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final periods = state.selectedPeriods;
    var budgets = state.budgets
        .where((b) => periods.contains(YearMonth(b.year, b.month)))
        // Los planes de Inversión/Deuda tienen su propia tarjeta especial
        // (_DebtTile/_GoalTile) más abajo — aquí solo se listan los planes
        // de Gasto normal (incluye "Otros").
        .where((b) => !b.isDebtInstallment && !b.isGoalContribution)
        .toList();
    var debts = state.debts.toList();
    var goals = state.goals.toList();

    if (_hasAdvancedFilters) {
      budgets = budgets
          .where(
            (b) => _matchesAdvanced(
              category: b.category,
              subcategory: b.subcategory,
              country: b.country,
              status: b.status,
            ),
          )
          .toList();
      debts = debts
          .where(
            (d) => _matchesAdvanced(category: d.category, country: d.country),
          )
          .toList();
      goals = goals
          .where(
            (g) => _matchesAdvanced(category: g.category, country: g.country),
          )
          .toList();
    }

    // Fuente única de verdad: mismo cálculo que usa el resto del app
    // (por budgetItemId, con fallback a categoría+subcategoría solo para
    // transacciones sin vínculo explícito) — evita duplicar lógica y
    // asegura que reasignar una transacción de "Otros" a otro plan
    // actualice ambos indicadores correctamente.
    double realizadoFor(BudgetItem b) => state.realizadoForBudgetItem(b);

    final showGastos =
        _filter == _PlanFilter.todos || _filter == _PlanFilter.gastos;
    final showDeudas =
        _filter == _PlanFilter.todos || _filter == _PlanFilter.deudas;
    final showObjetivos =
        _filter == _PlanFilter.todos || _filter == _PlanFilter.objetivos;

    final isEmptyForFilter =
        (!showGastos || budgets.isEmpty) &&
        (!showDeudas || debts.isEmpty) &&
        (!showObjetivos || goals.isEmpty);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Mesmo componente/estilo/posição do botão "+" de Nova transação
      // (FAB circular padrão do tema, sem cor customizada) — a diferenciação
      // visual entre Transações e Planificación vem do header, ícones e
      // organização dos cartões, não de uma cor de FAB diferente.
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PlanFormScreen())),
        child: const Icon(Icons.savings_rounded),
      ),
      bottomNavigationBar: _selectionMode && _selectedIds.isNotEmpty
          ? _BulkActionBar(
              count: _selectedIds.length,
              onReplicate: () => _showBulkReplicateOptions(
                context,
                state,
                _selectedIds.toList(),
              ),
              onDelete: () =>
                  _confirmBulkDelete(context, state, _selectedIds.toList()),
              onCancel: _toggleSelectionMode,
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          100,
        ),
        children: [
          if (state.hasPendingPlanificacion) ...[
            _PendingPlanificacionSection(state: state),
            const SizedBox(height: AppSpacing.xxl),
          ],
          ScreenHeader(
            icon: Icons.assignment_rounded,
            iconColor: AppColors.inversion,
            title: 'Planificación',
            subtitle:
                'Organiza tus gastos, objetivos y deudas antes de que ocurran.',
            trailing: const PeriodSelector(inline: true),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (showGastos)
                IconButton(
                  onPressed: budgets.isEmpty ? null : _toggleSelectionMode,
                  icon: Icon(
                    _selectionMode
                        ? Icons.close_rounded
                        : Icons.checklist_rounded,
                    size: 20,
                  ),
                  tooltip: _selectionMode ? 'Cancelar' : 'Seleccionar',
                ),
              IconButton(
                onPressed: () => _applySuggestion(context, state),
                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                tooltip: 'Sugerir próximo mes',
              ),
            ],
          ),
          // Filtro segmentado (Todos / Gastos / Dívidas / Objetivos), em
          // linha única — igual ao padrão adotado em Transações — mais o
          // botão de filtros avançados (categoria/subcategoria/país/status
          // + replicação).
          SegmentedFilterBar<_PlanFilter>(
            options: const [
              FilterOption(_PlanFilter.todos, 'Todos'),
              FilterOption(_PlanFilter.gastos, 'Gastos'),
              FilterOption(_PlanFilter.objetivos, 'Objetivos'),
              FilterOption(_PlanFilter.deudas, 'Deudas'),
            ],
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
            onAdvancedTap: () => _openAdvancedFilters(context, state),
            advancedActive: _hasAdvancedFilters,
          ),
          const SizedBox(height: AppSpacing.md),
          if (isEmptyForFilter)
            SectionCard(child: Text(_emptyMessageFor(_filter)))
          else ...[
            if (showGastos)
              ...budgets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _BudgetPlanCard(
                    item: b,
                    realizado: realizadoFor(b),
                    txnCount: state.txnCountForBudgetItem(b),
                    selectionMode: _selectionMode,
                    selected: _selectedIds.contains(b.id),
                    onToggleSelected: () => _toggleSelected(b.id),
                    onLongPress: () {
                      if (!_selectionMode) {
                        setState(() {
                          _selectionMode = true;
                          _selectedIds.add(b.id);
                        });
                      }
                    },
                  ),
                ),
              ),
            if (showDeudas)
              ...debts.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _DebtPlanCard(debt: d),
                ),
              ),
            if (showObjetivos)
              ...goals.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _GoalPlanCard(goal: g),
                ),
              ),
            // O botão "Novo plano" foi removido daqui: o FAB no canto
            // inferior direito (definido no Scaffold acima) é agora o
            // único ponto de entrada para criar uma planificación, igual
            // ao padrão usado em Transações.
            const SizedBox(height: AppSpacing.xxl),
          ],
        ],
      ),
    );
  }

  String _emptyMessageFor(_PlanFilter f) {
    switch (f) {
      case _PlanFilter.gastos:
        return 'No hay gastos planificados para este período.';
      case _PlanFilter.deudas:
        return 'No hay deudas registradas.';
      case _PlanFilter.objetivos:
        return 'No hay objetivos de inversión creados.';
      case _PlanFilter.todos:
        return 'No hay ninguna planificación para este período.';
    }
  }

  /// Painel único de "filtros avançados" de Planificación — além dos
  /// filtros comuns (categoria/subcategoria/país/status), inclui também a
  /// replicação (próximo mes/meses específicos/vários consecutivos), que
  /// deixa de ter um botão dedicado próprio no header.
  void _openAdvancedFilters(BuildContext context, AppState state) {
    final categories = state.expenseCategories;
    final countries = state.countries;
    showAdvancedFiltersSheet(
      context,
      title: 'Filtros avanzados',
      onClear: _clearAdvancedFilters,
      onApply: () => setState(() {}),
      builder: (ctx, setModalState) {
        return StatefulBuilder(
          builder: (ctx, localSet) {
            final subOptions = _advCategory == null
                ? <String>[]
                : (categories
                          .where((c) => c.name == _advCategory)
                          .map((c) => c.subcategories)
                          .firstOrNull ??
                      const <String>[]);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdvancedFilterLabel('Categoría'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: _advCategory == null,
                      onSelected: (_) {
                        setState(() {
                          _advCategory = null;
                          _advSubcategory = null;
                        });
                        localSet(() {});
                      },
                    ),
                    ...categories.map(
                      (c) => ChoiceChip(
                        label: Text(c.name),
                        selected: _advCategory == c.name,
                        onSelected: (_) {
                          setState(() {
                            _advCategory = c.name;
                            _advSubcategory = null;
                          });
                          localSet(() {});
                        },
                      ),
                    ),
                  ],
                ),
                if (subOptions.isNotEmpty) ...[
                  const AdvancedFilterLabel('Subcategoría'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('Todas'),
                        selected: _advSubcategory == null,
                        onSelected: (_) {
                          setState(() => _advSubcategory = null);
                          localSet(() {});
                        },
                      ),
                      ...subOptions.map(
                        (s) => ChoiceChip(
                          label: Text(s),
                          selected: _advSubcategory == s,
                          onSelected: (_) {
                            setState(() => _advSubcategory = s);
                            localSet(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const AdvancedFilterLabel('País'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _advCountry == null,
                      onSelected: (_) {
                        setState(() => _advCountry = null);
                        localSet(() {});
                      },
                    ),
                    ...countries.map(
                      (c) => ChoiceChip(
                        label: Text(c),
                        selected: _advCountry == c,
                        onSelected: (_) {
                          setState(() => _advCountry = c);
                          localSet(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const AdvancedFilterLabel('Status'),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _advStatus == null,
                      onSelected: (_) {
                        setState(() => _advStatus = null);
                        localSet(() {});
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Pagado'),
                      selected: _advStatus == TxStatus.pagado,
                      onSelected: (_) {
                        setState(() => _advStatus = TxStatus.pagado);
                        localSet(() {});
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Pendiente'),
                      selected: _advStatus == TxStatus.pendiente,
                      onSelected: (_) {
                        setState(() => _advStatus = TxStatus.pendiente);
                        localSet(() {});
                      },
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xxl),
                const AdvancedFilterLabel('Replicar planificación'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_all_rounded, size: 16),
                      label: const Text('Replicar (todo el mes)'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showReplicateOptions(context, state);
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Ponto de partida do fluxo de replicação: mostra as 5 opções previstas
  /// (próximo mes, varios meses consecutivos, meses específicos, año entero,
  /// selección manual). Todas terminam chamando [_confirmAndReplicate], que
  /// é o único caminho que efetivamente copia o planejamento — mantendo uma
  /// única fonte de verdade também para esta ação.
  void _showReplicateOptions(BuildContext context, AppState state) {
    final periods = state.selectedPeriods.toList()..sort();
    if (periods.isEmpty) return;
    final from = periods.last;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Replicar planificación de ${monthLabel(from)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward_rounded),
              title: const Text('Próximo mes'),
              subtitle: Text(monthLabel(from.next())),
              onTap: () {
                Navigator.pop(ctx);
                _confirmAndReplicate(context, state, from, [from.next()]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('Varios meses consecutivos'),
              onTap: () {
                Navigator.pop(ctx);
                _replicateConsecutive(context, state, from);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('Meses específicos'),
              onTap: () {
                Navigator.pop(ctx);
                _replicateSpecificMonths(context, state, from);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month_rounded),
              title: const Text('Año entero'),
              onTap: () {
                Navigator.pop(ctx);
                final targets = List.generate(12, (i) => from.addMonths(i + 1));
                _confirmAndReplicate(context, state, from, targets);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Selección manual'),
              onTap: () {
                Navigator.pop(ctx);
                _replicateManualSelection(context, state, from);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _replicateConsecutive(
    BuildContext context,
    AppState state,
    YearMonth from,
  ) async {
    final ctrl = TextEditingController(text: '3');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Varios meses consecutivos'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: '¿Cuántos meses?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text) ?? 0),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (n == null || n <= 0) return;
    final targets = List.generate(n, (i) => from.addMonths(i + 1));
    if (!context.mounted) return;
    await _confirmAndReplicate(context, state, from, targets);
  }

  Future<void> _replicateSpecificMonths(
    BuildContext context,
    AppState state,
    YearMonth from,
  ) async {
    final candidates = List.generate(24, (i) => from.addMonths(i + 1));
    final selected = <YearMonth>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Meses específicos'),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: ListView(
              children: candidates.map((ym) {
                final checked = selected.contains(ym);
                return CheckboxListTile(
                  value: checked,
                  title: Text(monthLabel(ym)),
                  onChanged: (v) => setLocal(() {
                    if (v == true) {
                      selected.add(ym);
                    } else {
                      selected.remove(ym);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selected.isEmpty) return;
    final targets = selected.toList()..sort();
    if (!context.mounted) return;
    await _confirmAndReplicate(context, state, from, targets);
  }

  Future<void> _replicateManualSelection(
    BuildContext context,
    AppState state,
    YearMonth from,
  ) async {
    final added = <YearMonth>[];
    var year = from.year;
    var month = from.next().month;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Selección manual'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: month,
                        decoration: const InputDecoration(labelText: 'Mes'),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(monthNamesEs[i + 1]),
                          ),
                        ),
                        onChanged: (v) => setLocal(() => month = v ?? month),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: year,
                        decoration: const InputDecoration(labelText: 'Año'),
                        items: List.generate(
                          6,
                          (i) => DropdownMenuItem(
                            value: from.year + i,
                            child: Text('${from.year + i}'),
                          ),
                        ),
                        onChanged: (v) => setLocal(() => year = v ?? year),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: () => setLocal(() {
                        final ym = YearMonth(year, month);
                        if (!added.contains(ym)) added.add(ym);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (added.isEmpty)
                  const Text('Ningún mes agregado todavía.')
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (added.toList()..sort())
                        .map(
                          (ym) => Chip(
                            label: Text(monthLabel(ym)),
                            onDeleted: () => setLocal(() => added.remove(ym)),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || added.isEmpty) return;
    final targets = added.toList()..sort();
    if (!context.mounted) return;
    await _confirmAndReplicate(context, state, from, targets);
  }

  /// Confirmação final e execução única — chamada por todos os fluxos de
  /// replicação acima, garantindo que a lógica de replicação em si exista
  /// em um único lugar (fonte única de verdade também no fluxo de UI).
  Future<void> _confirmAndReplicate(
    BuildContext context,
    AppState state,
    YearMonth from,
    List<YearMonth> targets,
  ) async {
    if (targets.isEmpty) return;
    final sorted = targets.toList()..sort();
    final label = sorted.length == 1
        ? monthLabel(sorted.first)
        : '${sorted.length} meses (${monthLabel(sorted.first)} – ${monthLabel(sorted.last)})';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replicar planificación'),
        content: Text(
          'Se copiará el presupuesto de ${monthLabel(from)} hacia $label. '
          'Las transacciones ejecutadas nunca se copian; cada mes quedará '
          'independiente después de la replicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replicar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.replicateBudgetToMany(from: from, targets: sorted);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Presupuesto replicado a $label.')),
        );
      }
    }
  }

  /// Aplica a sugestão automática de orçamento (baseada no histórico) para
  /// o mês seguinte ao último período selecionado — parte do "Planejamento
  /// Inteligente" que aprende com o histórico e sugere o próximo mês.
  Future<void> _applySuggestion(BuildContext context, AppState state) async {
    final periods = state.selectedPeriods.toList()..sort();
    final base = periods.isNotEmpty
        ? periods.last
        : YearMonth.fromDate(DateTime.now());
    final target = base.next();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sugerir próximo mes'),
        content: Text(
          'Con base en tu historial reciente, el sistema sugerirá automáticamente el presupuesto de ${monthLabel(target)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sugerir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.applyBudgetSuggestion(target);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Presupuesto de ${monthLabel(target)} sugerido automáticamente.',
            ),
          ),
        );
      }
    }
  }

  /// Selección múltiple > Replicar: mismas 4 opciones de destino que la
  /// replicación individual (próximo mes / varios consecutivos / meses
  /// específicos / selección manual), pero aplicadas SOLO a los ids
  /// seleccionados en vez de "todo el mes" — usa
  /// [AppState.replicateBudgetItemsToMany].
  void _showBulkReplicateOptions(
    BuildContext context,
    AppState state,
    List<String> ids,
  ) {
    final periods = state.selectedPeriods.toList()..sort();
    final from = periods.isNotEmpty
        ? periods.last
        : YearMonth.fromDate(DateTime.now());
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Replicar ${ids.length} planificación${ids.length == 1 ? '' : 'es'} seleccionada${ids.length == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward_rounded),
              title: const Text('Próximo mes'),
              subtitle: Text(monthLabel(from.next())),
              onTap: () {
                Navigator.pop(ctx);
                _confirmAndReplicateBulk(context, state, ids, [from.next()]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('Varios meses consecutivos'),
              onTap: () async {
                Navigator.pop(ctx);
                final ctrl = TextEditingController(text: '3');
                final n = await showDialog<int>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: const Text('Varios meses consecutivos'),
                    content: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '¿Cuántos meses?',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(dctx, int.tryParse(ctrl.text) ?? 0),
                        child: const Text('Continuar'),
                      ),
                    ],
                  ),
                );
                if (n == null || n <= 0 || !context.mounted) return;
                final targets = List.generate(n, (i) => from.addMonths(i + 1));
                await _confirmAndReplicateBulk(context, state, ids, targets);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('Meses específicos'),
              onTap: () async {
                Navigator.pop(ctx);
                final candidates = List.generate(
                  24,
                  (i) => from.addMonths(i + 1),
                );
                final selected = <YearMonth>{};
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => StatefulBuilder(
                    builder: (dctx, setLocal) => AlertDialog(
                      title: const Text('Meses específicos'),
                      content: SizedBox(
                        width: double.maxFinite,
                        height: 320,
                        child: ListView(
                          children: candidates.map((ym) {
                            final checked = selected.contains(ym);
                            return CheckboxListTile(
                              value: checked,
                              title: Text(monthLabel(ym)),
                              onChanged: (v) => setLocal(() {
                                if (v == true) {
                                  selected.add(ym);
                                } else {
                                  selected.remove(ym);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx, false),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dctx, true),
                          child: const Text('Continuar'),
                        ),
                      ],
                    ),
                  ),
                );
                if (ok != true || selected.isEmpty || !context.mounted) return;
                final targets = selected.toList()..sort();
                await _confirmAndReplicateBulk(context, state, ids, targets);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndReplicateBulk(
    BuildContext context,
    AppState state,
    List<String> ids,
    List<YearMonth> targets,
  ) async {
    if (targets.isEmpty) return;
    final sorted = targets.toList()..sort();
    final label = sorted.length == 1
        ? monthLabel(sorted.first)
        : '${sorted.length} meses (${monthLabel(sorted.first)} – ${monthLabel(sorted.last)})';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replicar planificaciones'),
        content: Text(
          'Se copiarán ${ids.length} planificación${ids.length == 1 ? '' : 'es'} seleccionada${ids.length == 1 ? '' : 's'} hacia $label, '
          'como registros nuevos e independientes. Las transacciones ejecutadas nunca se copian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replicar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final created = await state.replicateBudgetItemsToMany(
        budgetIds: ids,
        targets: sorted,
      );
      if (context.mounted) {
        setState(() {
          _selectionMode = false;
          _selectedIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$created planificación(es) creada(s) en $label.'),
          ),
        );
      }
    }
  }

  /// Selección múltiple > Eliminar: NUNCA elimina en silencio — igual que
  /// el flujo individual, si hay transacciones vinculadas se informa la
  /// cantidad total afectada antes de confirmar, y esas transacciones
  /// quedan marcadas como pendientes de reorganización (nunca se borran).
  Future<void> _confirmBulkDelete(
    BuildContext context,
    AppState state,
    List<String> ids,
  ) async {
    final affected = state.countTxnsAffectedByBudgetDeletion(ids);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '¿Eliminar ${ids.length} planificación${ids.length == 1 ? '' : 'es'}?',
        ),
        content: Text(
          affected > 0
              ? 'Esto solo elimina los ítems de planificación seleccionados. '
                    '$affected transacción${affected == 1 ? '' : 'es'} ya registrada${affected == 1 ? '' : 's'} '
                    'NO se eliminará${affected == 1 ? '' : 'n'} ni afectará${affected == 1 ? '' : 'n'} tus KPIs — '
                    'quedará${affected == 1 ? '' : 'n'} marcada${affected == 1 ? '' : 's'} como "Pendente de '
                    'planificación" para que puedas volver a organizarlas.'
              : 'Esto solo elimina los ítems de planificación seleccionados. '
                    'No hay transacciones vinculadas a estos ítems.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.gasto),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.deleteBudgetsBulk(ids);
      if (context.mounted) {
        setState(() {
          _selectionMode = false;
          _selectedIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ids.length} planificación(es) eliminada(s).'),
          ),
        );
      }
    }
  }
}

/// Barra de acciones inferior mostrada durante la selección múltiple en
/// Planificación: replicar en masa o eliminar en masa los ítems marcados.
class _BulkActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onReplicate;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _BulkActionBar({
    required this.count,
    required this.onReplicate,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$count seleccionada${count == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onReplicate,
              icon: const Icon(Icons.copy_all_rounded, size: 17),
              label: const Text('Replicar'),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 17,
                color: AppColors.gasto,
              ),
              label: const Text(
                'Eliminar',
                style: TextStyle(color: AppColors.gasto),
              ),
            ),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Cancelar selección',
            ),
          ],
        ),
      ),
    );
  }
}



/// Cartão de plano de tipo Gasto — estilo fiel ao mockup "PLANOS": ícone
/// circular colorido, título/subtítulo, badge de tipo no topo-direita,
/// valor atual alinhado à direita, barra de progresso e linha inferior com
/// contagem de transações + data de vencimento. Toque abre a tela dedicada
/// "Detalhes do Plano" (nunca expande inline).
class _BudgetPlanCard extends StatelessWidget {
  final BudgetItem item;
  final double realizado;
  final int txnCount;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelected;
  final VoidCallback? onLongPress;

  const _BudgetPlanCard({
    required this.item,
    required this.realizado,
    this.txnCount = 0,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
    this.onLongPress,
  });

  String _iconKey(BuildContext context) {
    final state = context.read<AppState>();
    final match = state.expenseCategories.where((c) => c.name == item.category);
    return match.isNotEmpty ? match.first.icon : 'category';
  }

  @override
  Widget build(BuildContext context) {
    final b = item;
    final diff = b.planned - realizado;
    final progress = b.planned <= 0 ? 0.0 : realizado / b.planned;
    final overflow = realizado > b.planned;
    final covered = b.planned > 0 && realizado >= b.planned - 0.01;
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;

    return _PlanCardShell(
      selectionMode: selectionMode,
      selected: selected,
      onToggleSelected: onToggleSelected,
      onLongPress: onLongPress,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PlanDetailScreen.budget(b))),
      leadingIconKey: _iconKey(context),
      leadingColor: AppColors.gasto,
      title: '${b.category} · ${b.subcategory}',
      subtitle: b.autoSuggested ? 'Sugerido automáticamente' : 'Mensual',
      topBadgeLabel: 'Gasto',
      topBadgeColor: AppColors.gasto,
      currentValue: formatUsd(realizado, decimals: false),
      totalValue: formatUsd(b.planned, decimals: false),
      progress: progress,
      progressColor: overflow ? AppColors.gasto : AppColors.gasto,
      bottomLeftLabel: overflow
          ? 'Excedido +${formatUsd(-diff, decimals: false)}'
          : covered
          ? 'Cubierto'
          : 'Faltan ${formatUsd(diff, decimals: false)}',
      bottomLeftColor: overflow ? AppColors.gasto : mutedColor,
      bottomRightLabel: txnCount > 0
          ? '$txnCount transacci${txnCount == 1 ? 'ón' : 'ones'}'
          : 'Sin transacciones',
      dueDate: b.dueDate,
    );
  }
}

/// Cartão de plano de tipo Dívida — mesmo layout base, cor amarela/warning,
/// mostrando total pago vs. total e contagem de cuotas.
class _DebtPlanCard extends StatelessWidget {
  final Debt debt;
  const _DebtPlanCard({required this.debt});

  @override
  Widget build(BuildContext context) {
    return _PlanCardShell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PlanDetailScreen.debt(debt))),
      leadingIconKey: 'account_balance',
      leadingColor: AppColors.warning,
      title: debt.name,
      subtitle: '${debt.category} · Todos los días ${debt.startDate.day}',
      topBadgeLabel: 'Deuda',
      topBadgeColor: AppColors.warning,
      currentValue: formatUsd(debt.paidAmount, decimals: false),
      totalValue: formatUsd(debt.totalAmount, decimals: false),
      progress: debt.progress,
      progressColor: AppColors.warning,
      bottomLeftLabel: debt.isSettled
          ? 'Liquidada'
          : 'Faltan ${formatUsd(debt.remainingAmount, decimals: false)}',
      bottomLeftColor: debt.isSettled ? AppColors.ingreso : null,
      bottomRightLabel: '${debt.paidInstallments}/${debt.months} cuotas',
    );
  }
}

/// Cartão de plano de tipo Objetivo — mesmo layout base, cor azul, com
/// meta/acumulado e data final.
class _GoalPlanCard extends StatelessWidget {
  final InvestmentGoal goal;
  const _GoalPlanCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final completed = goal.isCompleted;
    return _PlanCardShell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PlanDetailScreen.goal(goal))),
      leadingIconKey: 'trending_up',
      leadingColor: AppColors.inversion,
      title: goal.name,
      subtitle: 'Objetivo',
      topBadgeLabel: 'Objetivo',
      topBadgeColor: AppColors.inversion,
      currentValue: formatUsd(goal.currentAmount, decimals: false),
      totalValue: formatUsd(goal.targetAmount, decimals: false),
      progress: goal.progress,
      progressColor: AppColors.inversion,
      bottomLeftLabel: completed
          ? (goal.isExceeded ? 'Meta superada' : 'Meta alcanzada')
          : 'Faltan ${formatUsd(goal.remaining, decimals: false)}',
      bottomLeftColor: completed ? AppColors.ingreso : null,
      bottomRightLabel: '',
      dueDate: goal.targetDate,
    );
  }
}

/// Layout compartilhado por [_BudgetPlanCard]/[_DebtPlanCard]/[_GoalPlanCard]
/// — segue o mockup "PLANOS": ícone circular + título/subtítulo à esquerda,
/// badge de tipo no topo-direita, valor atual/total à direita, barra de
/// progresso, e linha inferior com contagem/estado à esquerda e data à
/// direita.
class _PlanCardShell extends StatelessWidget {
  final VoidCallback onTap;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelected;
  final VoidCallback? onLongPress;
  final String leadingIconKey;
  final Color leadingColor;
  final String title;
  final String subtitle;
  final String topBadgeLabel;
  final Color topBadgeColor;
  final String currentValue;
  final String totalValue;
  final double progress;
  final Color progressColor;
  final String bottomLeftLabel;
  final Color? bottomLeftColor;
  final String bottomRightLabel;
  final DateTime? dueDate;

  const _PlanCardShell({
    required this.onTap,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
    this.onLongPress,
    required this.leadingIconKey,
    required this.leadingColor,
    required this.title,
    required this.subtitle,
    required this.topBadgeLabel,
    required this.topBadgeColor,
    required this.currentValue,
    required this.totalValue,
    required this.progress,
    required this.progressColor,
    required this.bottomLeftLabel,
    this.bottomLeftColor,
    required this.bottomRightLabel,
    this.dueDate,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: InkWell(
        onTap: selectionMode ? onToggleSelected : onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectionMode) ...[
                  Checkbox(
                    value: selected,
                    onChanged: (_) => onToggleSelected?.call(),
                  ),
                  const SizedBox(width: 2),
                ],
                CategoryIcon(
                  iconKey: leadingIconKey,
                  color: leadingColor,
                  size: 34,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: mutedColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                PlanBadge(label: topBadgeLabel, color: topBadgeColor),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currentValue,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: progressColor,
                  ),
                ),
                Text(
                  ' / $totalValue',
                  style: TextStyle(fontSize: 11.5, color: mutedColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ProgressBarWithOverflow(
              value: progress,
              color: progressColor,
              height: 7,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    bottomLeftLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: bottomLeftColor ?? mutedColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (bottomRightLabel.isNotEmpty)
                  Text(
                    bottomRightLabel,
                    style: TextStyle(fontSize: 10.5, color: mutedColor),
                  ),
                if (dueDate != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    formatFullDate(dueDate!),
                    style: TextStyle(fontSize: 10.5, color: mutedColor),
                  ),
                ],
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 15, color: mutedColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// planificaciones. Solo aparece cuando existen transacciones que perdieron
/// su vínculo con una planificación (generalmente porque esa planificación
/// fue eliminada). Vincular una transacción NUNCA altera ningún KPI — es
/// puramente una acción de organización.
class _PendingPlanificacionSection extends StatefulWidget {
  final AppState state;
  const _PendingPlanificacionSection({required this.state});

  @override
  State<_PendingPlanificacionSection> createState() =>
      _PendingPlanificacionSectionState();
}

class _PendingPlanificacionSectionState
    extends State<_PendingPlanificacionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final pending = state.txnsPendingPlanificacion;
    final count = pending.length;
    final total = state.pendingPlanificacionTotal;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transacciones pendientes',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          count == 1
                              ? '1 transacción necesita ser vinculada a una planificación'
                              : '$count transacciones necesitan ser vinculadas a una planificación',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatUsd(total, decimals: false),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'organizar',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warning.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 18,
                            color: AppColors.warning,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: pending
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _PendingTxnTile(txn: t, state: state),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tile de una transacción pendiente individual — permite vincularla a una
/// planificación existente del mismo mes/tipo, o crear una nueva y vincular
/// de inmediato. Una vez vinculada, desaparece automáticamente de la lista.
class _PendingTxnTile extends StatelessWidget {
  final Txn txn;
  final AppState state;
  const _PendingTxnTile({required this.txn, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${txn.category} · ${txn.subcategory}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatUsd(txn.amount, decimals: false)} · ${txn.movementTypeLabel}',
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => _showLinkOptions(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: const BorderSide(color: AppColors.warning),
            ),
            child: const Text(
              'Vincular',
              style: TextStyle(fontSize: 11.5, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  void _showLinkOptions(BuildContext context) {
    final ym = YearMonth(txn.year, txn.month);
    // Solo se sugieren planificaciones de Gasto normal del mismo mes que
    // encajen con el tipo de la transacción; deudas/objetivos ya tienen
    // sus propios vínculos automáticos (debtId/goalId) y no aparecen aquí.
    final candidates = state.budgets
        .where(
          (b) =>
              b.year == ym.year &&
              b.month == ym.month &&
              !b.isDebtInstallment &&
              !b.isGoalContribution,
        )
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vincular transacción',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${txn.category} · ${txn.subcategory} · '
                '${formatUsd(txn.amount, decimals: false)}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.md),
              if (candidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'No hay planificaciones existentes en este mes. '
                    'Crea una nueva para vincular esta transacción.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView(
                    shrinkWrap: true,
                    children: candidates
                        .map(
                          (b) => ListTile(
                            leading: const Icon(
                              Icons.link_rounded,
                              color: AppColors.gasto,
                            ),
                            title: Text('${b.category} · ${b.subcategory}'),
                            subtitle: Text(
                              formatUsd(b.planned, decimals: false),
                            ),
                            onTap: () {
                              state.linkTxnToBudget(txn.id, b.id);
                              Navigator.pop(ctx);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crear nueva planificación y vincular'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final created = await Navigator.of(context)
                        .push<BudgetItem>(
                          MaterialPageRoute(
                            builder: (_) => PlanFormScreen(
                              initialKind: PlanKind.gasto,
                              initialMonth: ym.month,
                              initialYear: ym.year,
                              initialCategory: txn.category,
                              initialSubcategory: txn.subcategory,
                              initialPlanned: txn.amount,
                            ),
                          ),
                        );
                    if (created != null) {
                      state.linkTxnToBudget(txn.id, created.id);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
