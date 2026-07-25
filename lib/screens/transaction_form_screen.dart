import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/transaction.dart';
import '../models/taxonomy.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/manage_lists_dialogs.dart';

const _uuid = Uuid();

/// Formulário completo de transação: usado tanto para criar como editar.
class TransactionFormScreen extends StatefulWidget {
  final Txn? existing;
  const TransactionFormScreen({super.key, this.existing});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TxType _type;
  late TxNature _nature;
  String? _category;
  String? _subcategory;
  late String _country;
  final _amountCtrl = TextEditingController();
  late DateTime _date;
  late PaymentMethod _method;
  late TxStatus _status;
  final _descCtrl = TextEditingController();
  String? _scope;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _type = t?.type ?? TxType.gasto;
    _nature = t?.nature ?? TxNature.variable;
    _category = t?.category;
    _subcategory = t?.subcategory;
    _country = t?.country ?? '';
    _amountCtrl.text = t != null ? t.amount.toStringAsFixed(2) : '';
    _date = t?.date ?? DateTime.now();
    _method = t?.method ?? PaymentMethod.efectivo;
    _status = t?.status ?? TxStatus.pendiente;
    _descCtrl.text = t?.description ?? '';
    _scope = t?.scope;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  List<CategoryDef> _cats(AppState state) => state.categoriesFor(_type);

  void _ensureDefaults(AppState state) {
    if (_country.isEmpty && state.countries.isNotEmpty)
      _country = state.countries.first;
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

  void _submit(AppState state) {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _subcategory == null || _country.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa categoría, subcategoría y país.'),
        ),
      );
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;

    final txn = Txn(
      id: widget.existing?.id ?? _uuid.v4(),
      type: _type,
      nature: _nature,
      status: _status,
      country: _country,
      category: _category!,
      subcategory: _subcategory!,
      amount: amount,
      date: _date,
      method: _method,
      description: _descCtrl.text.trim(),
      isPending: amount == 0,
      scope: _scope,
    );

    if (widget.existing != null) {
      state.updateTxn(txn);
    } else {
      state.addTxn(txn);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _ensureDefaults(state);
    final cats = _cats(state);
    final currentCat = cats.where((c) => c.name == _category);
    final subOptions = currentCat.isNotEmpty
        ? currentCat.first.subcategories
        : <String>[];

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
            const Text(
              'Tipo',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: TxType.values.map((t) {
                final selected = _type == t;
                return ChoiceChip(
                  label: Text(t.label),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _type = t;
                    _category = null;
                    _subcategory = null;
                  }),
                );
              }).toList(),
            ),
            if (_type == TxType.gasto || _type == TxType.deuda) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Naturaleza',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: TxNature.values.map((n) {
                  return ChoiceChip(
                    label: Text(n.label),
                    selected: _nature == n,
                    onSelected: (_) => setState(() => _nature = n),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
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
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _category = v;
                      _subcategory = null;
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
                      final cat = CategoryDef(name: name, subcategories: []);
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
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _subcategory = v),
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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: state.countries.contains(_country)
                        ? _country
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'País / Ubicación',
                    ),
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
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor total (USD)',
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
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Método de pago'),
              items: PaymentMethod.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                  .toList(),
              onChanged: (v) => setState(() => _method = v!),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Estado',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: TxStatus.values.map((s) {
                return ChoiceChip(
                  label: Text(s.label),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Ámbito (opcional)',
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
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _amountCtrl.clear();
                        _descCtrl.clear();
                        _status = TxStatus.pendiente;
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
