import 'enums.dart';

/// Representa uma transação financeira (ingreso, gasto, inversión ou deuda).
/// Campos essenciais aparecem sempre no formulário; os demais ficam em
/// "Más opciones" para manter o cadastro extremamente simples.
class Txn {
  String id;
  TxType type;
  TxStatus status;
  String country;
  String category;
  String subcategory;
  double amount;
  DateTime date;
  PaymentMethod method;
  String description;
  bool isPending; // valor $0 "a programar"
  bool isDeficitRollover; // gerado automaticamente por rollover de déficit
  String? scope; // Personal | Empresa (opcional)
  String? debtId; // vincula a parcela a uma Deuda (quando aplicável)
  String? goalId; // vincula um aporte a um Objetivo (quando aplicável)
  String?
  budgetItemId; // vincula explicitamente a um ítem da Planificación (BudgetItem)

  Txn({
    required this.id,
    required this.type,
    required this.status,
    required this.country,
    required this.category,
    required this.subcategory,
    required this.amount,
    required this.date,
    this.method = PaymentMethod.efectivo,
    this.description = '',
    this.isPending = false,
    this.isDeficitRollover = false,
    this.scope,
    this.debtId,
    this.goalId,
    this.budgetItemId,
  });

  int get month => date.month;
  int get year => date.year;

  double get signedAmount => type.isInflow ? amount : -amount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'status': status.name,
    'country': country,
    'category': category,
    'subcategory': subcategory,
    'amount': amount,
    'date': date.toIso8601String(),
    'method': method.name,
    'description': description,
    'isPending': isPending,
    'isDeficitRollover': isDeficitRollover,
    'scope': scope,
    'debtId': debtId,
    'goalId': goalId,
    'budgetItemId': budgetItemId,
  };

  factory Txn.fromJson(Map<String, dynamic> json) => Txn(
    id: json['id'] as String,
    type: TxTypeX.fromString(json['type'] as String),
    status: TxStatusX.fromString(json['status'] as String? ?? 'pendiente'),
    country: json['country'] as String,
    category: json['category'] as String,
    subcategory: json['subcategory'] as String,
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    method: PaymentMethodX.fromString(json['method'] as String? ?? 'efectivo'),
    description: json['description'] as String? ?? '',
    isPending: json['isPending'] as bool? ?? false,
    isDeficitRollover: json['isDeficitRollover'] as bool? ?? false,
    scope: json['scope'] as String?,
    debtId: json['debtId'] as String?,
    goalId: json['goalId'] as String?,
    budgetItemId: json['budgetItemId'] as String?,
  );

  Txn copyWith({
    TxType? type,
    TxStatus? status,
    String? country,
    String? category,
    String? subcategory,
    double? amount,
    DateTime? date,
    PaymentMethod? method,
    String? description,
    bool? isPending,
    bool? isDeficitRollover,
    String? scope,
    String? debtId,
    String? goalId,
    String? budgetItemId,
  }) {
    return Txn(
      id: id,
      type: type ?? this.type,
      status: status ?? this.status,
      country: country ?? this.country,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      method: method ?? this.method,
      description: description ?? this.description,
      isPending: isPending ?? this.isPending,
      isDeficitRollover: isDeficitRollover ?? this.isDeficitRollover,
      scope: scope ?? this.scope,
      debtId: debtId ?? this.debtId,
      goalId: goalId ?? this.goalId,
      budgetItemId: budgetItemId ?? this.budgetItemId,
    );
  }
}
