import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/budget_item.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/taxonomy.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/period.dart';
import '../widgets/manage_lists_dialogs.dart';

const _uuid = Uuid();

/// Os 3 tipos de planejamento unificados neste formulário, conforme o
/// mockup "Novo planejamento": Gasto (vermelho), Dívida (âmbar) e Objetivo
/// (azul). Cada tipo revela apenas os campos que precisa — "campos extras
/// aparecem apenas quando necessário".
enum PlanKind { gasto, deuda, objetivo }

extension _PlanKindX on PlanKind {
  String get label {
    switch (this) {
      case PlanKind.gasto:
        return 'Gasto';
      case PlanKind.deuda:
        return 'Deuda';
      case PlanKind.objetivo:
        return 'Objetivo';
    }
  }

  Color get color {
    switch (this) {
      case PlanKind.gasto:
        return AppColors.gasto;
      case PlanKind.deuda:
        return AppColors.warning;
      case PlanKind.objetivo:
        return AppColors.inversion;
    }
  }
}

/// Formulário único de Planificación — unifica Gasto normal, Dívida e
/// Objetivo de inversión em uma única tela com seletor de tipo (3
/// segmentos coloridos), seguindo o mockup "Novo planejamento". O campo
/// Prioridade foi removido intencionalmente (não aparece mais na UI,
/// ainda que o modelo [BudgetItem.priority] permaneça com seu valor padrão
/// para não gerar churn no schema de dados).
class PlanFormScreen extends StatefulWidget {
  final BudgetItem? existingBudget;
  final Debt? existingDebt;
  final InvestmentGoal? existingGoal;
  final PlanKind? initialKind;
  // Prefill opcional (usado quando viene desde el formulario de transacción,
  // para crear un plan de Gasto nuevo sin duplicar la información).
  final int? initialMonth;
  final int? initialYear;
  final String? initialCategory;
  final String? initialSubcategory;
  final String? initialCountry;
  final double? initialPlanned;

  const PlanFormScreen({
    super.key,
    this.initialKind,
    this.initialMonth,
    this.initialYear,
    this.initialCategory,
    this.initialSubcategory,
    this.initialCountry,
    this.initialPlanned,
  }) : existingBudget = null,
       existingDebt = null,
       existingGoal = null;

  const PlanFormScreen.editBudget(BudgetItem item, {super.key})
    : existingBudget = item,
      existingDebt = null,
      existingGoal = null,
      initialKind = null,
      initialMonth = null,
      initialYear = null,
      initialCategory = null,
      initialSubcategory = null,
      initialCountry = null,
      initialPlanned = null;

  const PlanFormScreen.editDebt(Debt d, {super.key})
    : existingBudget = null,
      existingDebt = d,
      existingGoal = null,
      initialKind = null,
      initialMonth = null,
      initialYear = null,
      initialCategory = null,
      initialSubcategory = null,
      initialCountry = null,
      initialPlanned = null;

  const PlanFormScreen.editGoal(InvestmentGoal g, {super.key})
    : existingBudget = null,
      existingDebt = null,
      existingGoal = g,
      initialKind = null,
      initialMonth = null,
      initialYear = null,
      initialCategory = null,
      initialSubcategory = null,
      initialCountry = null,
      initialPlanned = null;

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late PlanKind _kind;
  bool get _isEditing =>
      widget.existingBudget != null ||
      widget.existingDebt != null ||
      widget.existingGoal != null;

  // ------- Campos comuns (Categoria/Subcategoria/País) -------
  String? _category;
  String? _subcategory;
  late String _country;

  // ------- Nome do plano (Dívida/Objetivo) -------
  final _nameCtrl = TextEditingController();

  // ------- Valor (planejado/total/meta) -------
  final _valueCtrl = TextEditingController();

  // ------- Gasto: período + vencimento -------
  late int _month;
  late int _year;
  DateTime? _dueDate;

  // ------- Dívida/Objetivo: data de término -------
  final DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  // ------- Descrição (posição depende do tipo) -------
  final _descCtrl = TextEditingController();

  bool _moreOptions = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBudget;
    final d = widget.existingDebt;
    final g = widget.existingGoal;

    _kind = b != null
        ? PlanKind.gasto
        : d != null
        ? PlanKind.deuda
        : g != null
        ? PlanKind.objetivo
        : widget.initialKind ?? PlanKind.gasto;

    // Comuns
    _category = b?.category ?? d?.category ?? g?.category ?? widget.initialCategory;
    _subcategory =
        b?.subcategory ?? d?.subcategory ?? g?.subcategory ?? widget.initialSubcategory;
    _country = b?.country ?? d?.country ?? g?.country ?? widget.initialCountry ?? '';
    _descCtrl.text = b?.description ?? d?.description ?? g?.description ?? '';

    // Gasto
    _month = b?.month ?? widget.initialMonth ?? DateTime.now().month;
    _year = b?.year ?? widget.initialYear ?? DateTime.now().year;
    _dueDate = b?.dueDate;

    // Nome (Dívida/Objetivo)
    _nameCtrl.text = d?.name ?? g?.name ?? '';

    // Valor
    if (b != null) {
      _valueCtrl.text = b.planned.toStringAsFixed(2);
    } else if (d != null) {
      _valueCtrl.text = d.totalAmount.toStringAsFixed(2);
    } else if (g != null) {
      _valueCtrl.text = g.targetAmount.toStringAsFixed(2);
    } else if (widget.initialPlanned != null) {
      _valueCtrl.text = widget.initialPlanned!.toStringAsFixed(2);
    }

    // Dívida: data final a partir da data de início original (fonte única
    // de verdade: startDate + months, sem precisar de campo separado).
    if (d != null) {
      _endDate = DateTime(
        d.startDate.year,
        d.startDate.month + d.months,
        d.startDate.day,
      );
    }
    // Objetivo: data-objetivo diretamente.
    if (g != null) {
      _endDate = g.targetDate;
    }

    _valueCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

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

  double get _numericValue =>
      double.tryParse(_valueCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _currentAmount => widget.existingGoal?.currentAmount ?? 0;
  double get _paidAmount => widget.existingDebt?.paidAmount ?? 0;

  /// Data de início de referência da dívida — usada como âncora para
  /// calcular a quantidade de meses a partir da data de término escolhida
  /// (fonte única de verdade: sem campo redundante de "quantidade de meses").
  DateTime get _debtStartRef => widget.existingDebt?.startDate ?? _startDate;

  int _monthsBetween(DateTime from, DateTime to) {
    final m = (to.year - from.year) * 12 + (to.month - from.month);
    return m < 1 ? 1 : m;
  }

  /// Quantidade de meses da dívida, calculada diretamente a partir da data
  /// de início e da data de término — nunca editada manualmente.
  int get _debtMonths {
    if (_endDate == null) return widget.existingDebt?.months ?? 1;
    return _monthsBetween(_debtStartRef, _endDate!);
  }

  /// Meses restantes até a data-objetivo, contados a partir de hoje.
  int get _goalMonthsFromNow {
    if (_endDate == null) return 1;
    return _monthsBetween(DateTime.now(), _endDate!);
  }

  double get _monthlyInstallmentPreview {
    final months = _debtMonths;
    if (months <= 0) return _numericValue;
    return _numericValue / months;
  }

  double get _monthlyTargetPreview {
    final remaining = (_numericValue - _currentAmount).clamp(0, double.infinity);
    if (remaining <= 0) return 0;
    final months = _goalMonthsFromNow;
    if (months <= 0) return remaining * 0.1;
    return remaining / months;
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

  /// Data de término (Dívida/Objetivo) — único campo para definir o prazo;
  /// a quantidade de meses é sempre derivada automaticamente desta data.
  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 180)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  void _submit(AppState state) async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _country.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa categoría y país.')),
      );
      return;
    }
    if (_kind == PlanKind.deuda && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de término.')),
      );
      return;
    }

    switch (_kind) {
      case PlanKind.gasto:
        if (_subcategory == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Completa subcategoría.')),
          );
          return;
        }
        final item = BudgetItem(
          id: widget.existingBudget?.id ?? _uuid.v4(),
          month: _month,
          year: _year,
          category: _category!,
          subcategory: _subcategory!,
          country: _country,
          planned: _numericValue,
          dueDate: _dueDate,
          description: _descCtrl.text.trim(),
        );
        if (widget.existingBudget != null) {
          await state.updateBudget(item);
        } else {
          await state.addBudget(item);
        }
        if (!mounted) return;
        Navigator.of(context).pop(item);
        return;
      case PlanKind.deuda:
        final debt = Debt(
          id: widget.existingDebt?.id ?? _uuid.v4(),
          name: _nameCtrl.text.trim(),
          category: _category!,
          subcategory: _subcategory ?? '',
          country: _country,
          totalAmount: _numericValue,
          startDate: widget.existingDebt?.startDate ?? _startDate,
          months: _debtMonths,
          paidAmount: widget.existingDebt?.paidAmount ?? 0,
          description: _descCtrl.text.trim(),
        );
        if (widget.existingDebt != null) {
          await state.updateDebt(debt);
        } else {
          await state.addDebt(debt);
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      case PlanKind.objetivo:
        final goal = InvestmentGoal(
          id: widget.existingGoal?.id ?? _uuid.v4(),
          name: _nameCtrl.text.trim(),
          targetAmount: _numericValue,
          currentAmount: _currentAmount,
          targetDate: _endDate,
          description: _descCtrl.text.trim(),
          category: _category!,
          subcategory: _subcategory ?? '',
          country: _country,
        );
        if (widget.existingGoal != null) {
          await state.updateGoal(goal);
        } else {
          await state.addGoal(goal);
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppState state) async {
    final String title;
    final String message;
    final Future<void> Function() onConfirm;
    switch (_kind) {
      case PlanKind.gasto:
        title = '¿Eliminar planificación?';
        message =
            'Esto solo elimina el ítem de planificación. Las transacciones '
            'ya registradas NO se eliminan ni afectan tus KPIs — quedarán '
            'marcadas como "Pendente de planificación" para que puedas '
            'volver a organizarlas.';
        onConfirm = () => state.deleteBudget(widget.existingBudget!.id);
        break;
      case PlanKind.deuda:
        title = '¿Eliminar deuda?';
        message =
            'Esto solo elimina la deuda y sus cuotas planificadas. Las '
            'transacciones ya registradas (pagos ya hechos) NO se eliminan '
            'ni afectan tus KPIs — quedarán marcadas como "Pendente de '
            'planificación" para que puedas volver a organizarlas.';
        onConfirm = () => state.deleteDebt(widget.existingDebt!.id);
        break;
      case PlanKind.objetivo:
        title = '¿Eliminar objetivo?';
        message =
            'Esto solo elimina el objetivo de inversión. Las transacciones '
            'ya registradas (aportes/rescates) NO se eliminan ni afectan '
            'tus KPIs — quedarán marcadas como "Pendente de planificación" '
            'para que puedas volver a organizarlas.';
        onConfirm = () => state.deleteGoal(widget.existingGoal!.id);
        break;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.gasto)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onConfirm();
      if (context.mounted) Navigator.of(context).pop();
    }
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
    final kindColor = _kind.color;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar plan' : 'Nueva planificación'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ------- Seletor de tipo (3 segmentos coloridos) -------
            IgnorePointer(
              ignoring: _isEditing,
              child: Opacity(
                opacity: _isEditing ? 0.55 : 1,
                child: Row(
                  children: PlanKind.values.map((k) {
                    final selected = _kind == k;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: k != PlanKind.objetivo ? AppSpacing.sm : 0,
                        ),
                        child: ChoiceChip(
                          label: Text(k.label),
                          selected: selected,
                          selectedColor: k.color,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : k.color,
                            fontWeight: FontWeight.w700,
                          ),
                          side: BorderSide(color: k.color.withValues(alpha: 0.5)),
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ------- Row 1: Nome/Categoria + Data -------
            if (_kind != PlanKind.gasto) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do plano',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa un nombre'
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: InkWell(
                      onTap: _pickEndDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de término',
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _endDate != null
                                    ? formatFullDate(_endDate!)
                                    : 'Sin definir',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Categoria'),
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
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: subOptions.contains(_subcategory)
                          ? _subcategory
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Subcategoria (opcional)',
                      ),
                      items: subOptions
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _subcategory = v),
                    ),
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
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _kind == PlanKind.deuda
                            ? 'Valor total (USD)'
                            : 'Valor meta (USD)',
                        prefixText: '\$ ',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa un valor';
                        }
                        if (double.tryParse(v.replaceAll(',', '.')) == null) {
                          return 'Valor inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ------- Campos específicos por tipo -------
              if (_kind == PlanKind.deuda)
                _SpecificFieldsBox(
                  title: 'CAMPOS ESPECÍFICOS DA DÍVIDA',
                  color: kindColor,
                  children: [
                    // Mesma posição/estrutura do campo de Descrição do
                    // Objetivo, para que Dívida e Objetivo transmitam
                    // exatamente a mesma experiência de uso.
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        hintText: 'Ex: Financiamento del auto',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (widget.existingDebt != null) ...[
                      _ReadOnlyInfoCard(
                        label: 'Pago até agora',
                        value: formatUsd(_paidAmount, decimals: false),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_numericValue > 0 && _endDate != null)
                      _MonthlyPreviewCard(
                        label: 'Cuota mensual calculada',
                        value: _monthlyInstallmentPreview,
                        color: kindColor,
                      )
                    else
                      Text(
                        'Selecciona la fecha de término arriba para calcular la cuota mensual.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                  ],
                ),
              if (_kind == PlanKind.objetivo)
                _SpecificFieldsBox(
                  title: 'CAMPOS ESPECÍFICOS DO OBJETIVO',
                  color: kindColor,
                  children: [
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        hintText: 'Ex: Comprar notebook para trabalho',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (widget.existingGoal != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ReadOnlyInfoCard(
                        label: 'Valor atual guardado',
                        value: formatUsd(_currentAmount, decimals: false),
                      ),
                    ],
                    if (_monthlyTargetPreview > 0) ...[
                      const SizedBox(height: AppSpacing.md),
                      _MonthlyPreviewCard(
                        label: 'Aporte mensual sugerido',
                        value: _monthlyTargetPreview,
                        color: kindColor,
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: AppSpacing.md),
            ],

            // ------- Gasto: Categoria/Subcategoria/País/Valor/Período -------
            if (_kind == PlanKind.gasto) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
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
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: subOptions.contains(_subcategory)
                          ? _subcategory
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Subcategoria',
                      ),
                      items: subOptions
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _subcategory = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
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
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor planejado (USD)',
                        prefixText: '\$ ',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa un valor';
                        }
                        if (double.tryParse(v.replaceAll(',', '.')) == null) {
                          return 'Valor inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      decoration: const InputDecoration(labelText: 'Mês'),
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
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ------- Más opciones (colapsable) -------
            // Presente APENAS para Gasto (Ano/Vencimento/Descrição). Dívida
            // e Objetivo já mostram sua Descrição diretamente dentro de
            // "CAMPOS ESPECÍFICOS", sem nenhuma seção colapsável adicional
            // — garantindo que ambos ofereçam exatamente a mesma
            // experiência de uso.
            if (_kind == PlanKind.gasto) ...[
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
                DropdownButtonFormField<int>(
                  initialValue: _year,
                  decoration: const InputDecoration(labelText: 'Ano'),
                  items: List.generate(9, (i) => DateTime.now().year - 2 + i)
                      .map(
                        (y) => DropdownMenuItem(value: y, child: Text('$y')),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _year = v!),
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: _pickDueDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Vencimento (opcional)',
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
            ],

            Row(
              children: [
                if (_isEditing)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context, state),
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
                if (_isEditing) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kindColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _submit(state),
                    child: Text(
                      _isEditing
                          ? 'Guardar cambios'
                          : _kind == PlanKind.gasto
                          ? 'Agregar al presupuesto'
                          : _kind == PlanKind.deuda
                          ? 'Crear deuda'
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

/// Caixa destacada de "campos específicos" — reproduz o bloco
/// "CAMPOS ESPECÍFICOS DO OBJETIVO" do mockup, reutilizado também para
/// Dívida ("CAMPOS ESPECÍFICOS DA DÍVIDA"). Só aparece quando o tipo de
/// plano selecionado precisa desses campos extras.
class _SpecificFieldsBox extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> children;
  const _SpecificFieldsBox({
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// Card de solo lectura para valores calculados automáticamente (fuente
/// única de verdad) que el usuario NO puede editar manualmente — "Pago até
/// agora" (Dívida) o "Valor atual guardado" (Objetivo).
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

/// Card que exibe, em linguagem simples, o valor mensal sugerido — cuota
/// mensal calculada (Dívida) ou aporte mensual sugerido (Objetivo).
class _MonthlyPreviewCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MonthlyPreviewCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, color: color, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  formatUsd(value, decimals: false),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
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
