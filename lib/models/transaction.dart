import 'enums.dart';

/// Representa uma transação financeira (ingreso, gasto, inversión ou deuda).
class Txn {
  String id;
  TxType type;
  TxNature nature;
  TxStatus status;
  String country;
  String category;
  String subcategory;
  double amount;
  DateTime date; // usamos o dia 1 do mês/ano de referência + dia real se houver
  PaymentMethod method;
  String description;
  bool isPending; // valor $0 "a programar"
  bool isDeficitRollover; // gerado automaticamente por rollover de déficit
  String? scope; // Personal | Empresa (opcional, filtro rápido)

  Txn({
    required this.id,
    required this.type,
    required this.nature,
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
  });

  int get month => date.month;
  int get year => date.year;

  /// Valor com sinal: positivo para ingreso, negativo para gasto/deuda/inversion.
  double get signedAmount {
    if (type.isInflow) return amount;
    return -amount;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'nature': nature.name,
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
  };

  factory Txn.fromJson(Map<String, dynamic> json) => Txn(
    id: json['id'] as String,
    type: TxTypeX.fromString(json['type'] as String),
    nature: TxNatureX.fromString(json['nature'] as String),
    status: TxStatusX.fromString(json['status'] as String),
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
  );

  Txn copyWith({
    TxType? type,
    TxNature? nature,
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
  }) {
    return Txn(
      id: id,
      type: type ?? this.type,
      nature: nature ?? this.nature,
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
    );
  }
}
