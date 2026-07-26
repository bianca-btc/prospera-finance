import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/transaction.dart';
import '../models/budget_item.dart';
import '../models/taxonomy.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/period.dart';
import '../widgets/manage_lists_dialogs.dart';
import 'budget_form_screen.dart';

const _uuid = Uuid();

/// Formulário de transação: extremamente simples por defecto. El PRIMER
/// campo es siempre la selección de un plan de Planificación ya existente
/// (si la persona ya planificó, los demás campos se autocompletan). Si la
/// transacción está fuera de cualquier plan, se ofrece crear uno nuevo o,
/// en su defecto, cae automáticamente en el plan genérico "Otros" — así
/// TODA transacción queda siempre vinculada a un plan, sin duplicar
/// información ni trabajo.
class TransactionFormScreen extends StatefulWidget {
  final Txn? existing;
  const TransactionFormScreen({super.key, this.existing});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedBudgetId; // vínculo explícito con un ítem de Planificación
  late TxType _type;
  String? _category;
  String? _subcategory;
  late String _country;
  final _amountCtrl = TextEditingController();
  late DateTime _date;
  late PaymentMethod _method;
  final _descCtrl = TextEditingController();
  String? _scope;
  bool _moreOptions = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _type = t?.type ?? TxType.gasto;
    _category = t?.category;
    _subcategory = t?.subcategory;
    _country = t?.country ?? '';
    _amountCtrl.text = t != null ? t.amount.toStringAsFixed(2) : '';
    _date = t?.date ?? DateTime.now();
    _method = t?.method ?? PaymentMethod.efectivo;
    _descCtrl.text = t?.description ?? '';
    _scope = t?.scope;
    _selectedBudgetId = t?.budgetItemId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// Una transacción existente de tipo Inversión/Deuda fue generada
  /// automáticamente desde su propia planificación (Aportar/Rescatar/
  /// Realizar pago) y su vínculo (budgetItemId/debtId/goalId) no debe
  /// reasignarse desde esta pantalla — solo se puede editar monto, fecha,
  /// método, etc. El selector de plan queda oculto para evitar confusión
  /// y roturas del vínculo.
  bool get _isLockedType =>
      widget.existing != null &&
      widget.existing!.type != TxType.ingreso &&
      widget.existing!.type != TxType.gasto;

  List<CategoryDef> _cats(AppState state) => state.categoriesFor(_type);

  void _ensureDefaults(AppState state) {
    if (_country.isEmpty && state.countries.isNotEmpty) {
      _country = state.countries.first;
    }
    final cats = _cats(state);
    if (_category == null || !cats.any((c) => c.name == _category)) {
      _category = cats.isNotEmpty ? cats.first.name : null;
    }
    final subs = cats.where((c) => c.name == _category).toList();
    if (subs.isNotEmpty) {
      if (_subcategory == null ||
          !subs.first.subcategories.contains(_subcategory)) {
        _subcategory = subs.first.subcategories.isNotEmpty
            ? subs.first.subcategories.first
            : null;
      }
    } else {
      _subcategory = null;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Al seleccionar un plan existente en el primer campo, autocompleta
  /// categoría, subcategoría, país y (si el monto está vacío) el valor
  /// planificado — evitando duplicar el trabajo de planificación. El Tipo
  /// ya no se infiere del plan: Nueva Transacción solo crea Ingreso/Gasto
  /// (los movimientos de inversión/deuda se generan siempre desde dentro
  /// de su propia planificación, nunca aquí).
  void _applyBudgetSelection(AppState state, BudgetItem? item) {
    setState(() {
      _selectedBudgetId = item?.id;
      if (item == null) return;
      _category = item.category;
      _subcategory = item.subcategory;
      _country = item.country;
      if (_amountCtrl.text.trim().isEmpty && item.planned > 0) {
        _amountCtrl.text = item.planned.toStringAsFixed(2);
      }
    });
  }

  /// Limpia el vínculo de plan seleccionado si el usuario cambia manualmente
  /// la categoría/subcategoría, para no dejar un vínculo inconsistente.
  void _clearBudgetSelectionIfMismatched(AppState state) {
    if (_selectedBudgetId == null) return;
    final match = state.budgets.where((b) => b.id == _selectedBudgetId);
    if (match.isEmpty) return;
    final b = match.first;
    if (b.category != _category || b.subcategory != _subcategory) {
      _selectedBudgetId = null;
    }
  }

  Future<bool?> _confirmLinkDialog(BudgetItem match) {
    final label = match.subcategory.isNotEmpty
        ? match.subcategory
        : match.category;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Relacionar con planificación'),
        content: Text(
          'Encontramos un plan activo para "$label" en este mes. '
          '¿Deseas relacionar esta transacción con ese plan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, gracias'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, relacionar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _askCreatePlanDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sin plan vinculado'),
        content: const Text(
          'Esta transacción no está vinculada a ningún plan de '
          'planificación. ¿Deseas crear un plan para ella ahora? Si no, '
          'quedará dentro de un plan genérico "Otros".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Usar "Otros"'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear plan'),
          ),
        ],
      ),
    );
  }

  /// Garante que TODA transação (menos Ingreso) tenha um plan vinculado
  /// antes de salvar: usa o vínculo explícito escolhido no primeiro campo,
  /// senão tenta uma sugestão automática por categoria+subcategoria+mês,
  /// senão oferece criar um plan novo, senão cai no plan genérico "Otros".
  Future<
    ({String? budgetItemId, String? debtId, String? goalId})
  >
  _resolveBudgetLink(AppState state, double amount) async {
    if (_type == TxType.ingreso) {
      return (budgetItemId: null, debtId: null, goalId: null);
    }

    // 1) Vínculo explícito já escolhido no primeiro campo.
    if (_selectedBudgetId != null) {
      final match = state.budgets.where((b) => b.id == _selectedBudgetId);
      if (match.isNotEmpty) {
        return (
          budgetItemId: match.first.id,
          debtId: match.first.linkedDebtId,
          goalId: match.first.linkedGoalId,
        );
      }
    }

    // 2) Sugestão automática por categoria+subcategoria+mês.
    final draft = Txn(
      id: '_preview',
      type: _type,
      status: TxStatus.pagado,
      country: _country,
      category: _category!,
      subcategory: _subcategory ?? '',
      amount: amount,
      date: _date,
    );
    final suggestion = state.suggestBudgetLinkFor(draft);
    if (suggestion != null) {
      final confirmed = await _confirmLinkDialog(suggestion);
      if (confirmed == true) {
        return (
          budgetItemId: suggestion.id,
          debtId: suggestion.linkedDebtId,
          goalId: suggestion.linkedGoalId,
        );
      }
    }

    // 3) Ofrece crear un plan nuevo con los datos ya ingresados.
    if (!mounted) return (budgetItemId: null, debtId: null, goalId: null);
    final wantsCreate = await _askCreatePlanDialog();
    if (wantsCreate == true && mounted) {
      final created = await Navigator.of(context).push<BudgetItem>(
        MaterialPageRoute(
          builder: (_) => BudgetFormScreen(
            initialMonth: _date.month,
            initialYear: _date.year,
            initialCategory: _category,
            initialSubcategory: _subcategory,
            initialCountry: _country,
            initialPlanned: amount,
          ),
        ),
      );
      if (created != null) {
        return (
          budgetItemId: created.id,
          debtId: created.linkedDebtId,
          goalId: created.linkedGoalId,
        );
      }
    }

    // 4) Fallback: plan genérico "Otros" del mes correspondiente.
    final otros = await state.getOrCreateOtrosBudgetItem(
      ym: YearMonth.fromDate(_date),
      country: _country,
    );
    return (budgetItemId: otros.id, debtId: null, goalId: null);
  }

  Future<void> _submit(AppState state) async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _country.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa categoría y país.')),
      );
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;

    // Único punto de verdad: al editar, conserva el vínculo salvo que el
    // usuario lo haya cambiado explícitamente en el primer campo; al crear,
    // garantiza que la transacción quede vinculada a un plan (D).
    String? budgetItemId;
    String? debtId = widget.existing?.debtId;
    String? goalId = widget.existing?.goalId;

    if (widget.existing != null) {
      if (_isLockedType) {
        // Movimiento auto-generado (Aporte/Rescate/Pago): el vínculo con
        // su plan/objetivo/deuda NUNCA se reasigna desde esta pantalla,
        // sin importar el estado del selector (que además está oculto).
        budgetItemId = widget.existing!.budgetItemId;
        debtId = widget.existing!.debtId;
        goalId = widget.existing!.goalId;
      } else {
        budgetItemId = _selectedBudgetId ?? widget.existing?.budgetItemId;
        if (_selectedBudgetId != null) {
          final match = state.budgets.where((b) => b.id == _selectedBudgetId);
          if (match.isNotEmpty) {
            debtId = match.first.linkedDebtId;
            goalId = match.first.linkedGoalId;
          }
        }
      }
    } else {
      final link = await _resolveBudgetLink(state, amount);
      if (!mounted) return;
      budgetItemId = link.budgetItemId;
      debtId = link.debtId;
      goalId = link.goalId;
    }

    final txn = Txn(
      id: widget.existing?.id ?? _uuid.v4(),
      type: _type,
      status: TxStatus.pagado,
      country: _country,
      category: _category!,
      subcategory: _subcategory ?? '',
      amount: amount,
      date: _date,
      method: _method,
      description: _descCtrl.text.trim(),
      isPending: amount == 0,
      scope: _scope,
      debtId: debtId,
      goalId: goalId,
      budgetItemId: budgetItemId,
    );

    if (widget.existing != null) {
      state.updateTxn(txn);
    } else {
      state.addTxn(txn);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _ensureDefaults(state);
    _clearBudgetSelectionIfMismatched(state);
    final cats = _cats(state);
    final currentCat = cats.where((c) => c.name == _category);
    final subOptions = currentCat.isNotEmpty
        ? currentCat.first.subcategories
        : <String>[];

    // Solo planes de Gasto normal (y "Otros") son seleccionables desde
    // Nueva Transacción — los planes de Inversión/Deuda generan sus propios
    // movimientos automáticos (Aportar/Rescatar/Realizar pago) y nunca
    // deben recibir un gasto manual vinculado directamente.
    final availablePlans = state
        .budgetsForMonth(YearMonth.fromDate(_date))
        .where((b) => !b.isDebtInstallment && !b.isGoalContribution)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null ? 'Editar transacción' : 'Nueva transacción',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ------- Campo 1: Plan de Planificación (primero, según D) -------
            // Oculto para movimientos auto-generados (Aporte/Rescate/Pago):
            // su vínculo con la planificación se gestiona únicamente desde
            // dentro de esa planificación, nunca desde aquí.
            if (!_isLockedType) ...[
              const Text(
                'Plan de planificación',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue:
                    availablePlans.any((b) => b.id == _selectedBudgetId)
                        ? _selectedBudgetId
                        : null,
                decoration: const InputDecoration(
                  labelText: '¿Ya planificaste esto?',
                  helperText:
                      'Selecciona un plan existente para autocompletar los '
                      'demás campos, o déjalo en blanco si es nuevo.',
                  helperMaxLines: 2,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('— Fuera de un plan / nuevo —'),
                  ),
                  ...availablePlans.map(
                    (b) => DropdownMenuItem<String>(
                      value: b.id,
                      child: Text(
                        '${b.category} · ${b.subcategory} (${formatUsd(b.planned, decimals: false)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  final item = v == null
                      ? null
                      : availablePlans.firstWhere((b) => b.id == v);
                  _applyBudgetSelection(state, item);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.inversion.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.inversion.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 18,
                      color: AppColors.inversion,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Este movimiento está vinculado automáticamente a su '
                        'planificación y no puede reasignarse aquí.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.inversion),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ------- Campos obligatorios -------
            const Text(
              'Tipo',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              // Nueva Transacción solo admite Ingreso/Gasto — los
              // movimientos de Inversión (Aporte/Rescate) y Deuda (Pago)
              // se generan siempre desde dentro de su propia
              // planificación, nunca aquí. Si se está EDITANDO un
              // movimiento auto-generado (tipo inversión/deuda), se
              // muestra ese chip también pero sin permitir cambiar HACIA
              // esos tipos desde una transacción nueva.
              children: {
                TxType.ingreso,
                TxType.gasto,
                if (widget.existing != null) widget.existing!.type,
              }.map((t) {
                final selected = _type == t;
                final isEditableType =
                    t == TxType.ingreso || t == TxType.gasto;
                return ChoiceChip(
                  label: Text(
                    isEditableType ? t.label : widget.existing!.movementTypeLabel,
                  ),
                  selected: selected,
                  onSelected: isEditableType
                      ? (_) => setState(() {
                          _type = t;
                          _category = null;
                          _subcategory = null;
                          _selectedBudgetId = null;
                        })
                      : null,
                );
              }).toList(),
            ),
            if (widget.existing != null &&
                widget.existing!.type != TxType.ingreso &&
                widget.existing!.type != TxType.gasto) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Este movimiento fue generado automáticamente desde su '
                'planificación y no puede cambiar de tipo aquí.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            // Categoría y Subcategoría siempre adyacentes (F).
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: cats
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.name,
                            child: Text(c.isCustom ? c.name : '${c.name} *'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _category = v;
                      _subcategory = null;
                      _selectedBudgetId = null;
                    }),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Agregar categoría',
                  onPressed: () async {
                    final name = await showAddItemDialog(
                      context,
                      title: 'Nueva categoría',
                    );
                    if (name != null && name.isNotEmpty) {
                      final cat = CategoryDef(
                        name: name,
                        subcategories: [],
                        isCustom: true,
                      );
                      if (_type == TxType.ingreso) {
                        await state.addIncomeCategory(cat);
                      } else {
                        await state.addExpenseCategory(cat);
                      }
                      setState(() => _category = name);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: subOptions.contains(_subcategory)
                        ? _subcategory
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Subcategoría',
                    ),
                    items: subOptions
                        .map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _subcategory = v;
                      _selectedBudgetId = null;
                    }),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Agregar subcategoría',
                  onPressed: _category == null
                      ? null
                      : () async {
                          final name = await showAddItemDialog(
                            context,
                            title: 'Nueva subcategoría',
                          );
                          if (name != null && name.isNotEmpty) {
                            await state.addSubcategory(
                              isExpense: _type != TxType.ingreso,
                              category: _category!,
                              subcategory: name,
                            );
                            setState(() => _subcategory = name);
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor (USD)',
                prefixText: '\$ ',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa un valor';
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n == null) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha'),
                child: Row(
                  children: [
                    Text(formatFullDate(_date)),
                    const Spacer(),
                    const Icon(Icons.calendar_today_rounded, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: state.countries.contains(_country)
                        ? _country
                        : null,
                    decoration: const InputDecoration(labelText: 'País'),
                    items: state.countries
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _country = v!),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Agregar país',
                  onPressed: () async {
                    final name = await showAddItemDialog(
                      context,
                      title: 'Nuevo país',
                    );
                    if (name != null && name.isNotEmpty) {
                      await state.addCountry(name);
                      setState(() => _country = name);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ------- Más opciones (colapsable) -------
            InkWell(
              onTap: () => setState(() => _moreOptions = !_moreOptions),
              child: Row(
                children: [
                  Icon(
                    _moreOptions
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Más opciones',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (_moreOptions) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Método de pago'),
                items: PaymentMethod.values
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _method = v!),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Ámbito',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('Sin especificar'),
                    selected: _scope == null,
                    onSelected: (_) => setState(() => _scope = null),
                  ),
                  ChoiceChip(
                    label: const Text('Personal'),
                    selected: _scope == 'Personal',
                    onSelected: (_) => setState(() => _scope = 'Personal'),
                  ),
                  ChoiceChip(
                    label: const Text('Empresa'),
                    selected: _scope == 'Empresa',
                    onSelected: (_) => setState(() => _scope = 'Empresa'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _amountCtrl.clear();
                        _descCtrl.clear();
                      });
                    },
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _submit(state),
                    child: Text(
                      widget.existing != null
                          ? 'Guardar cambios'
                          : 'Agregar transacción',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
