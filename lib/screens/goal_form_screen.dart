import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/budget_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

const _uuid = Uuid();

class GoalFormScreen extends StatefulWidget {
  final InvestmentGoal? existing;
  const GoalFormScreen({super.key, this.existing});

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _nameCtrl.text = g?.name ?? '';
    _targetCtrl.text = g != null ? g.targetAmount.toStringAsFixed(2) : '';
    _currentCtrl.text = g != null ? g.currentAmount.toStringAsFixed(2) : '0';
    _descCtrl.text = g?.description ?? '';
    _targetDate = g?.targetDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _currentCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 180)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  void _submit(AppState state) {
    if (!_formKey.currentState!.validate()) return;
    final goal = InvestmentGoal(
      id: widget.existing?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      targetAmount: double.tryParse(_targetCtrl.text.replaceAll(',', '.')) ?? 0,
      currentAmount:
          double.tryParse(_currentCtrl.text.replaceAll(',', '.')) ?? 0,
      targetDate: _targetDate,
      description: _descCtrl.text.trim(),
    );
    if (widget.existing != null) {
      state.updateGoal(goal);
    } else {
      state.addGoal(goal);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null
              ? 'Editar objetivo'
              : 'Nuevo objetivo de inversión',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del objetivo',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Meta total (USD)',
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
              controller: _currentCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Acumulado actual (USD)',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha objetivo (opcional)',
                ),
                child: Row(
                  children: [
                    Text(
                      _targetDate != null
                          ? formatFullDate(_targetDate!)
                          : 'Sin definir',
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_today_rounded, size: 18),
                  ],
                ),
              ),
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
                        state.deleteGoal(widget.existing!.id);
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
                          : 'Crear objetivo',
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
