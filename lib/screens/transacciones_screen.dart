import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'transaction_form_screen.dart';

enum _QuickFilter {
  todos,
  gastos,
  ingresos,
  inversiones,
  deudas,
  personal,
  empresa,
}

class TransaccionesScreen extends StatefulWidget {
  const TransaccionesScreen({super.key});

  @override
  State<TransaccionesScreen> createState() => _TransaccionesScreenState();
}

class _TransaccionesScreenState extends State<TransaccionesScreen> {
  _QuickFilter _filter = _QuickFilter.todos;

  List<Txn> _applyFilter(List<Txn> list) {
    switch (_filter) {
      case _QuickFilter.todos:
        return list;
      case _QuickFilter.gastos:
        return list.where((t) => t.type == TxType.gasto).toList();
      case _QuickFilter.ingresos:
        return list.where((t) => t.type == TxType.ingreso).toList();
      case _QuickFilter.inversiones:
        return list.where((t) => t.type == TxType.inversion).toList();
      case _QuickFilter.deudas:
        return list.where((t) => t.type == TxType.deuda).toList();
      case _QuickFilter.personal:
        return list.where((t) => t.scope == 'Personal').toList();
      case _QuickFilter.empresa:
        return list.where((t) => t.scope == 'Empresa').toList();
    }
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
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                _filterChip('Todos', _QuickFilter.todos),
                _filterChip('Gastos', _QuickFilter.gastos),
                _filterChip('Ingresos', _QuickFilter.ingresos),
                _filterChip('Inversiones', _QuickFilter.inversiones),
                _filterChip('Deudas', _QuickFilter.deudas),
                _filterChip('Personal', _QuickFilter.personal),
                _filterChip('Empresa', _QuickFilter.empresa),
              ],
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

  Widget _filterChip(String label, _QuickFilter f) {
    final selected = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = f),
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
        return AppColors.inversion;
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
