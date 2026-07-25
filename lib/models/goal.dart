/// Objetivo financeiro (ex: Fondo de emergencia). O usuário informa apenas
/// o valor objetivo e o prazo; o app calcula automaticamente a meta mensal
/// necessária, recalculando os meses restantes sempre que o aporte de um
/// mês for maior ou menor que o previsto.
///
/// PRINCÍPIO DE FONTE ÚNICA DE VERDADE: [currentAmount] nunca é editado
/// manualmente pelo usuário — é sempre a soma das transações vinculadas
/// (Txn.goalId == this.id), mantida sincronizada automaticamente pelo
/// AppState sempre que uma transação vinculada é criada, editada ou
/// removida.
///
/// [category]/[subcategory]/[country] permitem que o objetivo gere
/// automaticamente itens de Planificación mensais (mesma lógica das
/// Deudas), para que o aporte mensual apareça no planejamento sem que o
/// usuário precise criá-lo manualmente.
class InvestmentGoal {
  String id;
  String name;
  double targetAmount;
  double currentAmount;
  DateTime startDate;
  DateTime? targetDate;
  String description;
  String icon;
  String category;
  String subcategory;
  String country;

  InvestmentGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    DateTime? startDate,
    this.targetDate,
    this.description = '',
    this.icon = 'flag',
    this.category = 'Inversiones',
    this.subcategory = '',
    this.country = '',
  }) : startDate = startDate ?? DateTime.now();

  double get remaining =>
      (targetAmount - currentAmount).clamp(0, double.infinity);
  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount);
  bool get isCompleted => currentAmount >= targetAmount;
  bool get isExceeded => currentAmount > targetAmount;

  /// Quantidade de meses restantes até a data-objetivo (mínimo 1).
  int get monthsRemaining {
    if (targetDate == null) return 1;
    final now = DateTime.now();
    final months =
        (targetDate!.year - now.year) * 12 + (targetDate!.month - now.month);
    return months < 1 ? 1 : months;
  }

  /// Meta mensal recalculada automaticamente com base no restante e nos
  /// meses até o prazo. Se não houver prazo definido, sugere 10% do valor
  /// restante por mês como referência razoável.
  double get monthlyTarget {
    if (remaining <= 0) return 0;
    if (targetDate == null) return remaining * 0.1;
    return remaining / monthsRemaining;
  }

  /// Lista de meses (mensal, a partir de [startDate] até [targetDate]) para
  /// os quais o aporte mensal deve ser adicionado automaticamente ao
  /// planejamento — mesma lógica das parcelas de Deudas.
  List<DateTime> contributionDates() {
    if (targetDate == null) return [startDate];
    final months =
        (targetDate!.year - startDate.year) * 12 +
        (targetDate!.month - startDate.month) +
        1;
    final n = months < 1 ? 1 : months;
    return List.generate(n, (i) {
      final m = startDate.month + i;
      final y = startDate.year + (m - 1) ~/ 12;
      final mm = ((m - 1) % 12) + 1;
      return DateTime(y, mm, startDate.day);
    });
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'targetAmount': targetAmount,
    'currentAmount': currentAmount,
    'startDate': startDate.toIso8601String(),
    'targetDate': targetDate?.toIso8601String(),
    'description': description,
    'icon': icon,
    'category': category,
    'subcategory': subcategory,
    'country': country,
  };

  factory InvestmentGoal.fromJson(Map<String, dynamic> json) => InvestmentGoal(
    id: json['id'] as String,
    name: json['name'] as String,
    targetAmount: (json['targetAmount'] as num).toDouble(),
    currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
    startDate: json['startDate'] != null
        ? DateTime.parse(json['startDate'] as String)
        : DateTime.now(),
    targetDate: json['targetDate'] != null
        ? DateTime.parse(json['targetDate'] as String)
        : null,
    description: json['description'] as String? ?? '',
    icon: json['icon'] as String? ?? 'flag',
    category: json['category'] as String? ?? 'Inversiones',
    subcategory: json['subcategory'] as String? ?? '',
    country: json['country'] as String? ?? '',
  );

  InvestmentGoal copyWith({
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? description,
    String? icon,
    String? category,
    String? subcategory,
    String? country,
  }) {
    return InvestmentGoal(
      id: id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate,
      targetDate: targetDate ?? this.targetDate,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      country: country ?? this.country,
    );
  }
}
