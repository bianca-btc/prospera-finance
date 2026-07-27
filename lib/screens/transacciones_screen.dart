import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/filter_bar.dart';
import '../widgets/period_selector.dart';
import 'transaction_form_screen.dart';

enum _QuickFilter { todos, gastos, ingresos, objetivos, deudas }

class TransaccionesScreen extends StatefulWidget {
  const TransaccionesScreen({super.key});

  @override
  State<TransaccionesScreen> createState() => _TransaccionesScreenState();
}

class _TransaccionesScreenState extends State<TransaccionesScreen> {
  _QuickFilter _filter = _QuickFilter.todos;

  // ------- Filtros avançados (categoria/subcategoria/país/ámbito) -------
  String? _scope; // Personal | Empresa | null (ambos)
  String? _advCategory;
  String? _advSubcategory;
  String? _advCountry;

  bool get _hasAdvancedFilters =>
      _scope != null ||
      _advCategory != null ||
      _advSubcategory != null ||
      _advCountry != null;

  void _clearAdvancedFilters() {
    _scope = null;
    _advCategory = null;
    _advSubcategory = null;
    _advCountry = null;
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
    if (_scope != null) {
      result = result.where((t) => t.scope == _scope);
    }
    if (_advCategory != null) {
      result = result.where((t) => t.category == _advCategory);
    }
    if (_advSubcategory != null) {
      result = result.where((t) => t.subcategory == _advSubcategory);
    }
    if (_advCountry != null) {
      result = result.where((t) => t.country == _advCountry);
    }
    return result.toList();
  }

  /// Painel de "filtros avançados" — segue exatamente o mesmo padrão visual
  /// e estrutural do painel de Planificación (AdvancedFilterLabel + Wrap de
  /// ChoiceChip, com opção "Todos/Todas" primeiro em cada grupo).
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
                const AdvancedFilterLabel('Ámbito'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _scope == null,
                      onSelected: (_) {
                        setState(() => _scope = null);
                        localSet(() {});
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Personal'),
                      selected: _scope == 'Personal',
                      onSelected: (_) {
                        setState(() => _scope = 'Personal');
                        localSet(() {});
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Empresa'),
                      selected: _scope == 'Empresa',
                      onSelected: (_) {
                        setState(() => _scope = 'Empresa');
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
              trailing: const PeriodSelector(inline: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SegmentedFilterBar<_QuickFilter>(
              options: const [
                FilterOption(_QuickFilter.todos, 'Todos'),
                FilterOption(_QuickFilter.gastos, 'Gastos'),
                FilterOption(_QuickFilter.ingresos, 'Ingresos'),
                FilterOption(_QuickFilter.objetivos, 'Objetivos'),
                FilterOption(_QuickFilter.deudas, 'Deudas'),
              ],
              selected: _filter,
              onChanged: (f) => setState(() => _filter = f),
              onAdvancedTap: () => _openAdvancedFilters(context, state),
              advancedActive: _hasAdvancedFilters,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
