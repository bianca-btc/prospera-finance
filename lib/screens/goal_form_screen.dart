import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/goal.dart';
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
  final _monthsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _targetDate;

  double _previewTarget = 0;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _nameCtrl.text = g?.name ?? '';
    _targetCtrl.text = g != null ? g.targetAmount.toStringAsFixed(2) : '';
    _descCtrl.text = g?.description ?? '';
    _targetDate = g?.targetDate;
    _monthsCtrl.text = g != null ? g.monthsRemaining.toString() : '';
    _previewTarget = g?.targetAmount ?? 0;
    _targetCtrl.addListener(_recalcPreview);
  }

  void _recalcPreview() {
    setState(() {
      _previewTarget =
          double.tryParse(_targetCtrl.text.replaceAll(',', '.')) ?? 0;
    });
  }

  /// Acumulado actual: NUNCA se edita manualmente (fuente única de
  /// verdad = suma de aportes/rescates vinculados). En creación siempre
  /// es 0; en edición, se muestra de solo lectura.
  double get _currentAmount => widget.existing?.currentAmount ?? 0;

  /// Cantidad de meses restantes hasta la fecha final elegida por el
  /// usuario (mínimo 1) — recalculada cada vez que cambia la fecha.
  int get _monthsFromDate {
    if (_targetDate == null) return 1;
    final now = DateTime.now();
    final months =
        (_targetDate!.year - now.year) * 12 + (_targetDate!.month - now.month);
    return months < 1 ? 1 : months;
  }

  /// Meta mensal automática — recalcula meses restantes se el aporte
  /// difiere del previsto (misma lógica de InvestmentGoal.monthlyTarget).
  double get _monthlyTargetPreview {
    final remaining = (_previewTarget - _currentAmount).clamp(
      0,
      double.infinity,
    );
    if (remaining <= 0) return 0;
    if (_targetDate == null) return remaining * 0.1;
    return remaining / _monthsFromDate;
  }

  @override
  void dispose() {
    _targetCtrl.removeListener(_recalcPreview);
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _monthsCtrl.dispose();
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
    if (picked != null) {
      setState(() {
        _targetDate = picked;
        _monthsCtrl.text = _monthsFromDate.toString();
      });
    }
  }

  /// Al editar "Cantidad de meses" manualmente, recalcula la fecha final
  /// correspondiente — mantiene ambos campos sincronizados con la misma
  /// fuente de verdad (siempre a partir de hoy).
  void _applyMonthsInput(String value) {
    final n = int.tryParse(value);
    if (n == null || n < 1) return;
    final now = DateTime.now();
    setState(() {
      _targetDate = DateTime(now.year, now.month + n, now.day);
    });
  }

  void _submit(AppState state) {
    if (!_formKey.currentState!.validate()) return;
    final goal = InvestmentGoal(
      id: widget.existing?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      targetAmount: double.tryParse(_targetCtrl.text.replaceAll(',', '.')) ?? 0,
      // Fuente única de verdad: nunca se asigna manualmente. En creación
      // siempre inicia en 0; en edición, se conserva el valor ya calculado.
      currentAmount: _currentAmount,
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
              controller: _monthsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad de meses',
                helperText: 'A partir de hoy. Calcula la fecha final automáticamente.',
                helperMaxLines: 2,
              ),
              onChanged: _applyMonthsInput,
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
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha final'),
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
            if (widget.existing != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ReadOnlyInfoCard(
                label: 'Acumulado actual',
                value: formatUsd(_currentAmount, decimals: false),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (_monthlyTargetPreview > 0)
              _MonthlyTargetPreviewCard(value: _monthlyTargetPreview),
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

/// Card de solo lectura para mostrar valores calculados automáticamente
/// (fuente única de verdad) que el usuario NO puede editar manualmente,
/// como el acumulado actual de un objetivo (siempre = suma de aportes -
/// rescates registrados).
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

/// Card que exibe, em linguagem simples, cuánto hay que aportar cada mes
/// para alcanzar el objetivo — sustituye el cálculo manual por una
/// recomendación directa (principio: "sustituir números por interpretaciones").
class _MonthlyTargetPreviewCard extends StatelessWidget {
  final double value;
  const _MonthlyTargetPreviewCard({required this.value});

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
            Icons.insights_rounded,
            color: AppColors.inversion,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aporte mensual sugerido',
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
