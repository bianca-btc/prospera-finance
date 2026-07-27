import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/filter_bar.dart';
import 'transaction_form_screen.dart';

// Ordem fixa do toggle, idêntica em Transacciones/Planificación/Análisis:
// Todos, Ingresos, Gastos, Objetivos, Deudas. Objetivos/Deudas fazem parte
// das transações (são apenas outro TxType), por isso pertencem aqui.
enum _QuickFilter { todos, ingresos, gastos, objetivos, deudas }

class TransaccionesScreen extends StatefulWidget {
  const TransaccionesScreen({super.key});

  @override
  State<TransaccionesScreen> createState() => _TransaccionesScreenState();
}

class _TransaccionesScreenState extends State<TransaccionesScreen> {
  _QuickFilter _filter = _QuickFilter.todos;

  // ------- Filtros avançados (categoria/subcategoria/país/ámbito) -------
  // Seleção múltipla: cada dimensão de filtro é um Set — vazio significa
  // "sem filtro nessa dimensão" (equivalente ao antigo "Todos"/null), e
  // qualquer quantidade de valores pode ser selecionada simultaneamente.
  final Set<String> _scope = {}; // Personal | Empresa
  final Set<String> _advCategory = {};
  final Set<String> _advSubcategory = {};
  final Set<String> _advCountry = {};

  bool get _hasAdvancedFilters =>
      _scope.isNotEmpty ||
      _advCategory.isNotEmpty ||
      _advSubcategory.isNotEmpty ||
      _advCountry.isNotEmpty;

  void _clearAdvancedFilters() {
    _scope.clear();
    _advCategory.clear();
    _advSubcategory.clear();
    _advCountry.clear();
  }

  List<Txn> _applyFilter(List<Txn> list) {
    Iterable<Txn> result = list;
    switch (_filter) {
      case _QuickFilter.todos:
        break;
      case _QuickFilter.gastos:
        result = result.where((t) => t.type == TxType.gasto);
      case _QuickFilter.ingresos:
        result = result.where((t) => t.type == TxType.ingreso);
      case _QuickFilter.objetivos:
        result = result.where((t) => t.type == TxType.inversion);
      case _QuickFilter.deudas:
        result = result.where((t) => t.type == TxType.deuda);
    }
    if (_scope.isNotEmpty) {
      result = result.where((t) => _scope.contains(t.scope));
    }
    if (_advCategory.isNotEmpty) {
      result = result.where((t) => _advCategory.contains(t.category));
    }
    if (_advSubcategory.isNotEmpty) {
      result = result.where((t) => _advSubcategory.contains(t.subcategory));
    }
    if (_advCountry.isNotEmpty) {
      result = result.where((t) => _advCountry.contains(t.country));
    }
    return result.toList();
  }

  /// Resumen financiero dinámico: calculado exclusivamente a partir de la
  /// lista YA filtrada (post-filtro/período), sin ninguna consulta extra.
  /// Fórmula por opción del toggle:
  /// - Todos: suma ingresos − suma gastos − suma pagos de deudas − suma
  ///   aportes a objetivos (misma fórmula que el Saldo Disponible global,
  ///   pero aplicada solo sobre [filtered], es decir, acotada al período y
  ///   filtro seleccionados).
  /// - Ingresos: suma de los ingresos (siempre positivo).
  /// - Gastos: suma de los gastos (siempre negativo).
  /// - Objetivos: suma de los aportes a objetivos (excluye rescates —
  ///   un rescate no es un "aporte").
  /// - Deudas: suma de los pagos de deudas (siempre negativo).
  ({String label, String value}) _summaryFor(List<Txn> filtered) {
    final ingresosSum = filtered
        .where((t) => t.type == TxType.ingreso)
        .fold(0.0, (s, t) => s + t.amount);
    final gastosSum = filtered
        .where((t) => t.type == TxType.gasto)
        .fold(0.0, (s, t) => s + t.amount);
    final deudasSum = filtered
        .where((t) => t.type == TxType.deuda)
        .fold(0.0, (s, t) => s + t.amount);
    final aportesObjetivosSum = filtered
        .where((t) => t.type == TxType.inversion && !t.isWithdrawal)
        .fold(0.0, (s, t) => s + t.amount);
    switch (_filter) {
      case _QuickFilter.ingresos:
        return (
          label: 'Ingresos',
          value: formatUsd(ingresosSum, decimals: false),
        );
      case _QuickFilter.gastos:
        return (
          label: 'Gastos',
          value: '-${formatUsd(gastosSum, decimals: false)}',
        );
      case _QuickFilter.objetivos:
        return (
          label: 'Objetivos',
          value: formatUsd(aportesObjetivosSum, decimals: false),
        );
      case _QuickFilter.deudas:
        return (
          label: 'Deudas',
          value: '-${formatUsd(deudasSum, decimals: false)}',
        );
      case _QuickFilter.todos:
        final balance =
            ingresosSum - gastosSum - deudasSum - aportesObjetivosSum;
        final value = balance < 0
            ? '-${formatUsd(balance.abs(), decimals: false)}'
            : formatUsd(balance, decimals: false);
        return (label: 'Balance', value: value);
    }
  }

  /// Painel de "filtros avançados" — segue exatamente o mesmo padrão visual
  /// e estrutural do painel de Planificación (AdvancedFilterLabel + Wrap de
  /// FilterChip com seleção MÚLTIPLA), com uma pastilha "Todos/Todas" que
  /// limpa a seleção daquela dimensão (equivalente a "sem filtro").
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
            final subOptions = _advCategory.isEmpty
                ? <String>{}
                : categories
                      .where((c) => _advCategory.contains(c.name))
                      .expand((c) => c.subcategories)
                      .toSet();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdvancedFilterLabel('Ámbito'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _scope.isEmpty,
                      onSelected: (_) {
                        setState(_scope.clear);
                        localSet(() {});
                      },
                    ),
                    for (final v in const ['Personal', 'Empresa'])
                      FilterChip(
                        label: Text(v),
                        selected: _scope.contains(v),
                        onSelected: (sel) {
                          setState(
                            () => sel ? _scope.add(v) : _scope.remove(v),
                          );
                          localSet(() {});
                        },
                      ),
                  ],
                ),
                const AdvancedFilterLabel('Categoría'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: _advCategory.isEmpty,
                      onSelected: (_) {
                        setState(() {
                          _advCategory.clear();
                          _advSubcategory.clear();
                        });
                        localSet(() {});
                      },
                    ),
                    ...categories.map(
                      (c) => FilterChip(
                        label: Text(c.name),
                        selected: _advCategory.contains(c.name),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _advCategory.add(c.name);
                            } else {
                              _advCategory.remove(c.name);
                              _advSubcategory.removeWhere(
                                (s) => c.subcategories.contains(s),
                              );
                            }
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
                        selected: _advSubcategory.isEmpty,
                        onSelected: (_) {
                          setState(_advSubcategory.clear);
                          localSet(() {});
                        },
                      ),
                      ...subOptions.map(
                        (s) => FilterChip(
                          label: Text(s),
                          selected: _advSubcategory.contains(s),
                          onSelected: (sel) {
                            setState(
                              () => sel
                                  ? _advSubcategory.add(s)
                                  : _advSubcategory.remove(s),
                            );
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
                      selected: _advCountry.isEmpty,
                      onSelected: (_) {
                        setState(_advCountry.clear);
                        localSet(() {});
                      },
                    ),
                    ...countries.map(
                      (c) => FilterChip(
                        label: Text(c),
                        selected: _advCountry.contains(c),
                        onSelected: (sel) {
                          setState(
                            () => sel
                                ? _advCountry.add(c)
                                : _advCountry.remove(c),
                          );
                          localSet(() {});
                        },
                      ),
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = [...state.txnsForSelectedPeriods]
      ..sort((a, b) => b.date.compareTo(a.date));
    final list = _applyFilter(all);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
        ),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ScreenHeader(
              icon: Icons.receipt_long_rounded,
              iconColor: AppColors.brandAmber,
              title: 'Transacciones',
              subtitle: 'Registra y controla todos tus movimientos financieros.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SegmentedFilterBar<_QuickFilter>(
              options: const [
                FilterOption(_QuickFilter.todos, 'Todos'),
                FilterOption(_QuickFilter.ingresos, 'Ingresos'),
                FilterOption(_QuickFilter.gastos, 'Gastos'),
                FilterOption(_QuickFilter.objetivos, 'Objetivos'),
                FilterOption(_QuickFilter.deudas, 'Deudas'),
              ],
              selected: _filter,
              onChanged: (f) => setState(() => _filter = f),
              onAdvancedTap: () => _openAdvancedFilters(context, state),
              advancedActive: _hasAdvancedFilters,
            ),
          ),
          // Resumen financiero discreto: una sola línea entre la barra de
          // filtros y la lista, calculada 100% a partir de `list` (ya
          // filtrada) — se recalcula automáticamente en cada rebuild
          // (cambio de toggle/filtro/período/CRUD), sin ninguna consulta
          // adicional. Sin card/borde/fondo — solo texto discreto.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_summaryFor(list).label}: ${_summaryFor(list).value}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      'No hay transacciones para este filtro.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      90,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _TxnTile(txn: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final Txn txn;
  const _TxnTile({required this.txn});

  /// Color semántico del movimiento: verde para dinero que entra
  /// (ingreso o rescate de inversión), rojo para gasto, azul para
  /// aporte de inversión o pago de deuda.
  Color _colorFor(Txn t) {
    if (t.isEffectivelyInflow) return AppColors.ingreso;
    switch (t.type) {
      case TxType.ingreso:
        return AppColors.ingreso;
      case TxType.gasto:
        return AppColors.gasto;
      case TxType.deuda:
        return AppColors.deuda;
      case TxType.inversion:
        return AppColors.inversion;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final color = _colorFor(txn);
    final cats = state.categoriesFor(txn.type);
    final catMatch = cats.where((c) => c.name == txn.category);
    final iconKey = catMatch.isNotEmpty ? catMatch.first.icon : 'category';

    return Dismissible(
      key: ValueKey(txn.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppColors.gasto.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.gasto),
      ),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Eliminar transacción'),
                content: const Text('¿Deseas eliminar esta transacción?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => context.read<AppState>().deleteTxn(txn.id),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionFormScreen(existing: txn),
          ),
        ),
        onLongPress: () => _showActions(context),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Franja de color a la izquierda: identifica el tipo de
              // movimiento (ingreso/gasto/deuda/inversión) de un vistazo,
              // sin tener que leer texto.
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      CategoryIcon(iconKey: iconKey, color: color, size: 40),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              txn.description.isNotEmpty
                                  ? txn.description
                                  : '${txn.category} · ${txn.subcategory}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${txn.movementTypeLabel} · ${formatDayMonth(txn.date)} · ${txn.country}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${txn.isEffectivelyInflow ? '+' : '-'}${formatUsd(txn.amount)}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TransactionFormScreen(existing: txn),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Duplicar'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<AppState>().duplicateTxn(txn.id);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.gasto,
                ),
                title: const Text(
                  'Eliminar',
                  style: TextStyle(color: AppColors.gasto),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<AppState>().deleteTxn(txn.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
