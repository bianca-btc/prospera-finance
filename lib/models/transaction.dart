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
  String description;
  bool isPending; // valor $0 "a programar"
  bool isDeficitRollover; // gerado automaticamente por rollover de déficit
  String? scope; // Personal | Empresa (opcional)
  String? debtId; // vincula a parcela a uma Deuda (quando aplicável)
  String? goalId; // vincula um aporte a um Objetivo (quando aplicável)
  String?
  budgetItemId; // vincula explicitamente a um ítem da Planificación (BudgetItem)

  /// Marca que esta transação PERDEU seu vínculo com uma Planificación
  /// (Presupuesto/Deuda/Objetivo) porque essa planificación foi excluída.
  /// É DISTINTO de [isPending] (que significa "valor $0, a programar").
  /// Uma transação com [needsPlanificacionLink] = true:
  /// - JÁ é uma transação financeira real e completa (já afetou os KPIs).
  /// - Precisa apenas ser vinculada (ou revinculada) a alguma planificación
  ///   para fins de organização — isso NUNCA altera nenhum KPI.
  bool needsPlanificacionLink;

  /// Distingue, dentro de un movimiento de tipo [TxType.inversion], si es
  /// un RETIRO (rescate) en lugar de un aporte. Un rescate:
  /// - Disminuye el saldo de la inversión ([goalId]).
  /// - Aumenta el saldo disponible del usuario (efecto contrario al aporte).
  /// Nunca se usa para [TxType.gasto]/[TxType.ingreso]/[TxType.deuda]
  /// (siempre false para esos tipos).
  bool isWithdrawal;

  Txn({
    required this.id,
    required this.type,
    required this.status,
    required this.country,
    required this.category,
    required this.subcategory,
    required this.amount,
    required this.date,
    this.description = '',
    this.isPending = false,
    this.isDeficitRollover = false,
    this.scope,
    this.debtId,
    this.goalId,
    this.budgetItemId,
    this.isWithdrawal = false,
    this.needsPlanificacionLink = false,
  });

  int get month => date.month;
  int get year => date.year;

  /// Un movimiento "cuenta" como entrada de dinero disponible cuando es un
  /// Ingreso o un Rescate de inversión (aunque su [type] técnico sea
  /// [TxType.inversion]). Úsese esto — y no [TxType.isInflow] directamente —
  /// para decidir signo/color en la UI y en los cálculos de saldo.
  bool get isEffectivelyInflow =>
      type == TxType.ingreso || (type == TxType.inversion && isWithdrawal);

  double get signedAmount => isEffectivelyInflow ? amount : -amount;

  /// Etiqueta de "Tipo de movimiento" pensada para el historial —
  /// distingue Aporte/Rescate de inversión y Pago de deuda, aunque el
  /// modelo interno siga usando solamente 4 [TxType].
  String get movementTypeLabel {
    switch (type) {
      case TxType.ingreso:
        return 'Ingreso';
      case TxType.gasto:
        return 'Gasto';
      case TxType.inversion:
        return isWithdrawal ? 'Rescate de inversión' : 'Aporte de inversión';
      case TxType.deuda:
        return 'Pago de deuda';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'status': status.name,
    'country': country,
    'category': category,
    'subcategory': subcategory,
    'amount': amount,
    'date': date.toIso8601String(),
    'description': description,
    'isPending': isPending,
    'isDeficitRollover': isDeficitRollover,
    'scope': scope,
    'debtId': debtId,
    'goalId': goalId,
    'budgetItemId': budgetItemId,
    'isWithdrawal': isWithdrawal,
    'needsPlanificacionLink': needsPlanificacionLink,
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
    description: json['description'] as String? ?? '',
    isPending: json['isPending'] as bool? ?? false,
    isDeficitRollover: json['isDeficitRollover'] as bool? ?? false,
    scope: json['scope'] as String?,
    debtId: json['debtId'] as String?,
    goalId: json['goalId'] as String?,
    budgetItemId: json['budgetItemId'] as String?,
    isWithdrawal: json['isWithdrawal'] as bool? ?? false,
    needsPlanificacionLink: json['needsPlanificacionLink'] as bool? ?? false,
  );

  Txn copyWith({
    TxType? type,
    TxStatus? status,
    String? country,
    String? category,
    String? subcategory,
    double? amount,
    DateTime? date,
    String? description,
    bool? isPending,
    bool? isDeficitRollover,
    String? scope,
    String? debtId,
    String? goalId,
    String? budgetItemId,
    bool? isWithdrawal,
    bool? needsPlanificacionLink,
    bool clearDebtId = false,
    bool clearGoalId = false,
    bool clearBudgetItemId = false,
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
      description: description ?? this.description,
      isPending: isPending ?? this.isPending,
      isDeficitRollover: isDeficitRollover ?? this.isDeficitRollover,
      scope: scope ?? this.scope,
      debtId: clearDebtId ? null : (debtId ?? this.debtId),
      goalId: clearGoalId ? null : (goalId ?? this.goalId),
      budgetItemId: clearBudgetItemId
          ? null
          : (budgetItemId ?? this.budgetItemId),
      isWithdrawal: isWithdrawal ?? this.isWithdrawal,
      needsPlanificacionLink:
          needsPlanificacionLink ?? this.needsPlanificacionLink,
    );
  }
}
