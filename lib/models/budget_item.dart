import 'enums.dart';

/// Item de planejamento (presupuesto) de gasto mensal para uma categoria.
///
/// PRINCÍPIO DE FONTE ÚNICA DE VERDADE: a Planificación é a base do
/// sistema — dívidas e objetivos nunca criam lançamentos "soltos"; eles
/// geram automaticamente um [BudgetItem] por mês através de [linkedDebtId]
/// / [linkedGoalId]. Esses vínculos (não mais texto livre em [description])
/// permitem que o AppState identifique com segurança quais itens de
/// planejamento pertencem a uma dívida/objetivo, sem depender de parsing
/// de strings.
class BudgetItem {
  String id;
  int month;
  int year;
  String category;
  String subcategory;
  String country;
  double planned;
  DateTime? dueDate;
  Priority priority;
  TxStatus status;
  String description;
  bool autoSuggested; // criado automaticamente pelo motor de sugestões
  String? linkedDebtId; // item gerado automaticamente por uma Deuda
  String? linkedGoalId; // item gerado automaticamente por um Objetivo

  BudgetItem({
    required this.id,
    required this.month,
    required this.year,
    required this.category,
    required this.subcategory,
    required this.country,
    required this.planned,
    this.dueDate,
    this.priority = Priority.media,
    this.status = TxStatus.pendiente,
    this.description = '',
    this.autoSuggested = false,
    this.linkedDebtId,
    this.linkedGoalId,
  });

  bool get isDebtInstallment => linkedDebtId != null;
  bool get isGoalContribution => linkedGoalId != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'month': month,
    'year': year,
    'category': category,
    'subcategory': subcategory,
    'country': country,
    'planned': planned,
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority.name,
    'status': status.name,
    'description': description,
    'autoSuggested': autoSuggested,
    'linkedDebtId': linkedDebtId,
    'linkedGoalId': linkedGoalId,
  };

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    // Migração retrocompatível: bases antigas guardavam o vínculo como
    // "debt:<id>" dentro de description.
    String? legacyDebtId;
    final desc = json['description'] as String? ?? '';
    if (desc.startsWith('debt:')) legacyDebtId = desc.substring(5);
    return BudgetItem(
      id: json['id'] as String,
      month: json['month'] as int,
      year: json['year'] as int,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      country: json['country'] as String,
      planned: (json['planned'] as num).toDouble(),
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      priority: PriorityX.fromString(json['priority'] as String? ?? 'media'),
      status: TxStatusX.fromString(json['status'] as String? ?? 'pendiente'),
      description: legacyDebtId != null ? '' : desc,
      autoSuggested: json['autoSuggested'] as bool? ?? false,
      linkedDebtId: json['linkedDebtId'] as String? ?? legacyDebtId,
      linkedGoalId: json['linkedGoalId'] as String?,
    );
  }

  BudgetItem copyWith({
    String? category,
    String? subcategory,
    String? country,
    double? planned,
    DateTime? dueDate,
    Priority? priority,
    TxStatus? status,
    String? description,
    bool? autoSuggested,
    String? linkedDebtId,
    String? linkedGoalId,
  }) {
    return BudgetItem(
      id: id,
      month: month,
      year: year,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      country: country ?? this.country,
      planned: planned ?? this.planned,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      description: description ?? this.description,
      autoSuggested: autoSuggested ?? this.autoSuggested,
      linkedDebtId: linkedDebtId ?? this.linkedDebtId,
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
    );
  }
}
