import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/budget_item.dart';
import '../models/taxonomy.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/period.dart';
import '../widgets/manage_lists_dialogs.dart';

const _uuid = Uuid();

/// Formulário completo de item de presupuesto (Planificación), com todos
/// os campos exigidos pelo brief (tipo, natureza, categoria, país, valor,
/// data, método de pagamento, estado, descrição, prioridade, vencimento).
class BudgetFormScreen extends StatefulWidget {
  final BudgetItem? existing;
  // Prefill opcional (usado quando viene desde el formulario de transacción,
  // para crear un plan nuevo sin duplicar la información ya ingresada).
  final int? initialMonth;
  final int? initialYear;
  final String? initialCategory;
  final String? initialSubcategory;
  final String? initialCountry;
  final double? initialPlanned;

  const BudgetFormScreen({
    super.key,
    this.existing,
    this.initialMonth,
    this.initialYear,
    this.initialCategory,
    this.initialSubcategory,
    this.initialCountry,
    this.initialPlanned,
  });

  @override
  State<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends State<BudgetFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late int _month;
  late int _year;
  String? _category;
  String? _subcategory;
  late String _country;
  final _plannedCtrl = TextEditingController();
  DateTime? _dueDate;
  late Priority _priority;
  final _descCtrl = TextEditingController();
  late PaymentMethod _method;
  bool _moreOptions = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _month = b?.month ?? widget.initialMonth ?? DateTime.now().month;
    _year = b?.year ?? widget.initialYear ?? DateTime.now().year;
    _category = b?.category ?? widget.initialCategory;
    _subcategory = b?.subcategory ?? widget.initialSubcategory;
    _country = b?.country ?? widget.initialCountry ?? '';
    _plannedCtrl.text = b != null
        ? b.planned.toStringAsFixed(2)
        : (widget.initialPlanned != null
              ? widget.initialPlanned!.toStringAsFixed(2)
              : '');
    _dueDate = b?.dueDate;
    _priority = b?.priority ?? Priority.media;
    _descCtrl.text = b?.description ?? '';
    _method = b?.method ?? PaymentMethod.efectivo;
  }

  @override
  void dispose() {
    _plannedCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _ensureDefaults(AppState state) {
    if (_country.isEmpty && state.countries.isNotEmpty)
      _country = state.countries.first;
    final cats = state.expenseCategories;
    if (_category == null || !cats.any((c) => c.name == _category)) {
      _category = cats.isNotEmpty ? cats.first.name : null;
    }
    final match = cats.where((c) => c.name == _category);
    if (match.isNotEmpty && match.first.subcategories.isNotEmpty) {
      if (_subcategory == null ||
          !match.first.subcategories.contains(_subcategory)) {
        _subcategory = match.first.subcategories.first;
      }
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime(_year, _month, 5),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _dueDate = picked);
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
    final planned =
        double.tryParse(_plannedCtrl.text.replaceAll(',', '.')) ?? 0;
    final item = BudgetItem(
      id: widget.existing?.id ?? _uuid.v4(),
      month: _month,
      year: _year,
      category: _category!,
      subcategory: _subcategory!,
      country: _country,
      planned: planned,
      dueDate: _dueDate,
      priority: _priority,
      description: _descCtrl.text.trim(),
      method: _method,
    );
    if (widget.existing != null) {
      state.updateBudget(item);
    } else {
      state.addBudget(item);
    }
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _ensureDefaults(state);
    final cats = state.expenseCategories;
    final currentCat = cats.where((c) => c.name == _category);
    final subOptions = currentCat.isNotEmpty
        ? currentCat.first.subcategories
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null
              ? 'Editar planificación'
              : 'Nueva planificación · Gasto normal',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ------- Campos esenciales: Nombre (categoría), Valor, Periodo -------
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Nombre / Categoría',
                    ),
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
                      await state.addExpenseCategory(
                        CategoryDef(name: name, subcategories: []),
                      );
                      setState(() => _category = name);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _plannedCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor planificado (USD)',
                prefixText: '\$ ',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa un valor';
                if (double.tryParse(v.replaceAll(',', '.')) == null) {
                  return 'Valor inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: const InputDecoration(labelText: 'Periodo · Mes'),
                    items: List.generate(12, (i) => i + 1)
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(monthNamesEs[m]),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _month = v!),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(labelText: 'Año'),
                    items: List.generate(9, (i) => DateTime.now().year - 2 + i)
                        .map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y')),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _year = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ------- Más opciones (colapsable): resto de campos avanzados -------
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
                      onChanged: (v) => setState(() => _subcategory = v),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: _category == null
                        ? null
                        : () async {
                            final name = await showAddItemDialog(
                              context,
                              title: 'Nueva subcategoría',
                            );
                            if (name != null && name.isNotEmpty) {
                              await state.addSubcategory(
                                isExpense: true,
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
                      decoration: const InputDecoration(labelText: 'País'),
                      items: state.countries
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _country = v!),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
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
              InkWell(
                onTap: _pickDueDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Vencimiento (opcional)',
                  ),
                  child: Row(
                    children: [
                      Text(
                        _dueDate != null
                            ? formatFullDate(_dueDate!)
                            : 'Sin definir',
                      ),
                      const Spacer(),
                      const Icon(Icons.calendar_today_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Prioridad',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: Priority.values
                    .map(
                      (p) => ChoiceChip(
                        label: Text(p.label),
                        selected: _priority == p,
                        onSelected: (_) => setState(() => _priority = p),
                      ),
                    )
                    .toList(),
              ),
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
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  alignLabelWithHint: true,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                if (widget.existing != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        state.deleteBudget(widget.existing!.id);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.gasto,
                      ),
                      label: const Text(
                        'Eliminar',
                        style: TextStyle(color: AppColors.gasto),
                      ),
                    ),
                  ),
                if (widget.existing != null)
                  const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _submit(state),
                    child: Text(
                      widget.existing != null
                          ? 'Guardar cambios'
                          : 'Agregar al presupuesto',
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
