import 'enums.dart';

/// Item de planejamento (presupuesto) de gasto mensal para uma categoria.
class BudgetItem {
  String id;
  int month;
  int year;
  String category;
  String subcategory;
  String country;
  double planned;
  TxNature nature;
  DateTime? dueDate;
  Priority priority;
  TxStatus status;
  String description;
  PaymentMethod method;

  BudgetItem({
    required this.id,
    required this.month,
    required this.year,
    required this.category,
    required this.subcategory,
    required this.country,
    required this.planned,
    this.nature = TxNature.variable,
    this.dueDate,
    this.priority = Priority.media,
    this.status = TxStatus.pendiente,
    this.description = '',
    this.method = PaymentMethod.efectivo,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'month': month,
    'year': year,
    'category': category,
    'subcategory': subcategory,
    'country': country,
    'planned': planned,
    'nature': nature.name,
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority.name,
    'status': status.name,
    'description': description,
    'method': method.name,
  };

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
    id: json['id'] as String,
    month: json['month'] as int,
    year: json['year'] as int,
    category: json['category'] as String,
    subcategory: json['subcategory'] as String,
    country: json['country'] as String,
    planned: (json['planned'] as num).toDouble(),
    nature: TxNatureX.fromString(json['nature'] as String? ?? 'variable'),
    dueDate: json['dueDate'] != null
        ? DateTime.parse(json['dueDate'] as String)
        : null,
    priority: PriorityX.fromString(json['priority'] as String? ?? 'media'),
    status: TxStatusX.fromString(json['status'] as String? ?? 'pendiente'),
    description: json['description'] as String? ?? '',
    method: PaymentMethodX.fromString(json['method'] as String? ?? 'efectivo'),
  );

  BudgetItem copyWith({
    String? category,
    String? subcategory,
    String? country,
    double? planned,
    TxNature? nature,
    DateTime? dueDate,
    Priority? priority,
    TxStatus? status,
    String? description,
    PaymentMethod? method,
  }) {
    return BudgetItem(
      id: id,
      month: month,
      year: year,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      country: country ?? this.country,
      planned: planned ?? this.planned,
      nature: nature ?? this.nature,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      description: description ?? this.description,
      method: method ?? this.method,
    );
  }
}

/// Objetivo de investimento (meta de longo prazo, ex: Fondo de emergencia).
class InvestmentGoal {
  String id;
  String name;
  double targetAmount;
  double currentAmount;
  DateTime? targetDate;
  String description;

  InvestmentGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
    this.description = '',
  });

  double get remaining =>
      (targetAmount - currentAmount).clamp(0, double.infinity);
  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'targetAmount': targetAmount,
    'currentAmount': currentAmount,
    'targetDate': targetDate?.toIso8601String(),
    'description': description,
  };

  factory InvestmentGoal.fromJson(Map<String, dynamic> json) => InvestmentGoal(
    id: json['id'] as String,
    name: json['name'] as String,
    targetAmount: (json['targetAmount'] as num).toDouble(),
    currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
    targetDate: json['targetDate'] != null
        ? DateTime.parse(json['targetDate'] as String)
        : null,
    description: json['description'] as String? ?? '',
  );

  InvestmentGoal copyWith({
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? description,
  }) {
    return InvestmentGoal(
      id: id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      description: description ?? this.description,
    );
  }
}
