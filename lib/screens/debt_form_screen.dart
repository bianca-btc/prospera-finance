import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/debt.dart';
import '../models/taxonomy.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/manage_lists_dialogs.dart';

const _uuid = Uuid();

/// Formulario de deuda: el usuario solo informa nombre, valor total, fecha
/// inicial y cantidad de meses — el sistema divide automáticamente en
/// cuotas mensuales iguales y las agrega al planeamiento (Planificación).
/// Ejemplo: USD 1200 en 12 meses → USD 100/mes, generado sin esfuerzo manual.
class DebtFormScreen extends StatefulWidget {
  final Debt? existing;
  const DebtFormScreen({super.key, this.existing});

  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String? _category;
  String? _subcategory;
  String _country = '';

  double _previewTotal = 0;
  int _previewMonths = 1;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    _nameCtrl.text = d?.name ?? '';
    _totalCtrl.text = d != null ? d.totalAmount.toStringAsFixed(2) : '';
    _monthsCtrl.text = d != null ? d.months.toString() : '';
    _descCtrl.text = d?.description ?? '';
    _category = d?.category;
    _subcategory = d?.subcategory;
    _country = d?.country ?? '';
    _previewTotal = d?.totalAmount ?? 0;
    _previewMonths = d?.months ?? 1;
    if (d != null) {
      _endDate = DateTime(
        d.startDate.year,
        d.startDate.month + d.months,
        d.startDate.day,
      );
    }
    _totalCtrl.addListener(_recalcPreview);
    _monthsCtrl.addListener(_recalcPreview);
  }

  void _recalcPreview() {
    setState(() {
      _previewTotal =
          double.tryParse(_totalCtrl.text.replaceAll(',', '.')) ?? 0;
      _previewMonths = int.tryParse(_monthsCtrl.text) ?? 1;
      if (_previewMonths < 1) _previewMonths = 1;
      _endDate = DateTime(
        _startDate.year,
        _startDate.month + _previewMonths,
        _startDate.day,
      );
    });
  }

  double get _monthlyInstallmentPreview =>
      _previewMonths <= 0 ? _previewTotal : _previewTotal / _previewMonths;

  void _ensureDefaults(AppState state) {
    if (_country.isEmpty && state.countries.isNotEmpty) {
      _country = state.countries.first;
    }
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

  @override
  void dispose() {
    _totalCtrl.removeListener(_recalcPreview);
    _monthsCtrl.removeListener(_recalcPreview);
    _nameCtrl.dispose();
    _totalCtrl.dispose();
    _monthsCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// Al elegir manualmente la fecha final, recalcula la cantidad de meses
  /// correspondiente a partir de hoy (fuente única de verdad: siempre el
  /// usuario ve ambos campos sincronizados).
  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 180)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    final months =
        (picked.year - _startDate.year) * 12 +
        (picked.month - _startDate.month);
    setState(() {
      _endDate = picked;
      _previewMonths = months < 1 ? 1 : months;
      _monthsCtrl.text = _previewMonths.toString();
    });
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
    final debt = Debt(
      id: widget.existing?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      category: _category!,
      subcategory: _subcategory!,
      country: _country,
      totalAmount: double.tryParse(_totalCtrl.text.replaceAll(',', '.')) ?? 0,
      startDate: widget.existing?.startDate ?? _startDate,
      months: int.tryParse(_monthsCtrl.text) ?? 1,
      paidAmount: widget.existing?.paidAmount ?? 0,
      description: _descCtrl.text.trim(),
    );
    if (widget.existing != null) {
      state.updateDebt(debt);
    } else {
      state.addDebt(debt);
    }
    Navigator.of(context).pop();
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
        title: Text(widget.existing != null ? 'Editar deuda' : 'Nueva deuda'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la deuda',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _totalCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor total (USD)',
                prefixText: '\$ ',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa un valor';
                if (double.tryParse(v.replaceAll(',', '.')) == null)
                  return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _monthsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad de meses',
                helperText: 'A partir de hoy. Calcula la fecha final automáticamente.',
                helperMaxLines: 2,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Ingresa la cantidad de meses';
                }
                final n = int.tryParse(v);
                if (n == null || n < 1) return 'Cantidad inválida';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: _pickEndDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha final'),
                child: Row(
                  children: [
                    Text(
                      _endDate != null
                          ? formatFullDate(_endDate!)
                          : 'Sin definir',
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_today_rounded, size: 18),
                  ],
                ),
              ),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ReadOnlyInfoCard(
                label: 'Pagado hasta ahora',
                value: formatUsd(
                  widget.existing!.paidAmount,
                  decimals: false,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (_previewTotal > 0)
              _MonthlyInstallmentPreviewCard(value: _monthlyInstallmentPreview),
            const SizedBox(height: AppSpacing.md),
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
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
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
                if (widget.existing != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        state.deleteDebt(widget.existing!.id);
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
                          : 'Crear deuda',
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

/// Card de solo lectura para mostrar valores calculados automáticamente
/// (fuente única de verdad) que el usuario NO puede editar manualmente,
/// como el monto ya pagado de una deuda (siempre = suma de pagos
/// registrados).
class _ReadOnlyInfoCard extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyInfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _MonthlyInstallmentPreviewCard extends StatelessWidget {
  final double value;
  const _MonthlyInstallmentPreviewCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.inversion.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inversion.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calculate_outlined,
            color: AppColors.inversion,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cuota mensual calculada',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  formatUsd(value, decimals: false),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inversion,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
