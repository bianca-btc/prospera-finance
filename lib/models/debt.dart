import '../utils/period.dart';

/// Dívida com parcelamento automático: o usuário informa apenas o valor
/// total, a data inicial e a quantidade de meses; o app divide o valor
/// igualmente e gera uma parcela mensal que entra automaticamente no
/// planejamento (Planificación).
///
/// PRINCÍPIO DE FONTE ÚNICA DE VERDADE: [paidAmount] nunca é editado
/// manualmente pelo usuário — é sempre a soma das transações vinculadas
/// (Txn.debtId == this.id), mantida sincronizada automaticamente pelo
/// AppState sempre que uma transação vinculada é criada, editada ou
/// removida. Assim, "cuota pagada", "valor restante" e "% concluído"
/// nunca precisam ser atualizados manualmente em mais de um lugar.
class Debt {
  String id;
  String name;
  String category;
  String subcategory;
  String country;
  double totalAmount;
  DateTime startDate;
  int months;
  double paidAmount; // soma automática das transacciones vinculadas
  String description;

  Debt({
    required this.id,
    required this.name,
    required this.category,
    required this.subcategory,
    required this.country,
    required this.totalAmount,
    required this.startDate,
    required this.months,
    this.paidAmount = 0,
    this.description = '',
  });

  double get monthlyInstallment =>
      months <= 0 ? totalAmount : totalAmount / months;
  double get remainingAmount =>
      (totalAmount - paidAmount).clamp(0, double.infinity);
  bool get isSettled => paidAmount >= totalAmount - 0.01;
  double get progress => totalAmount <= 0 ? 0 : (paidAmount / totalAmount);

  /// Quantas cuotas "completas" ya fueron cubiertas por el valor pagado —
  /// solo para mostrar "X/Y cuotas", no es una fuente de verdad en sí.
  int get paidInstallments {
    if (monthlyInstallment <= 0) return 0;
    return (paidAmount / monthlyInstallment).round().clamp(0, months);
  }

  /// Lista de meses (ano/mês) e valores das parcelas geradas por esta dívida.
  ///
  /// BUGFIX: usar `DateTime(y, mm, startDate.day)` diretamente causava
  /// "vencimentos fantasma" quando [startDate.day] não existe no mês de
  /// destino (ex.: dia 31 caindo num mês de 28/29/30 dias) — o Dart
  /// normaliza automaticamente a data para o mês SEGUINTE (ex.: 31 de
  /// fevereiro vira 2/3 de março), fazendo a parcela "vazar" para o mês
  /// errado e às vezes colidir com a parcela seguinte no mesmo mês
  /// (dedupe silencioso) enquanto o mês original fica sem nenhuma parcela.
  /// Corrigido limitando o dia ao último dia válido do mês de destino.
  List<DateTime> installmentDates() {
    return List.generate(months, (i) {
      final m = startDate.month + i;
      final y = startDate.year + (m - 1) ~/ 12;
      final mm = ((m - 1) % 12) + 1;
      return safeMonthDate(y, mm, startDate.day);
    });
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'subcategory': subcategory,
    'country': country,
    'totalAmount': totalAmount,
    'startDate': startDate.toIso8601String(),
    'months': months,
    'paidAmount': paidAmount,
    'description': description,
  };

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    subcategory: json['subcategory'] as String,
    country: json['country'] as String,
    totalAmount: (json['totalAmount'] as num).toDouble(),
    startDate: DateTime.parse(json['startDate'] as String),
    months: json['months'] as int,
    // Migração retrocompatível: bases antigas guardavam paidInstallments (int).
    paidAmount: json['paidAmount'] != null
        ? (json['paidAmount'] as num).toDouble()
        : ((json['paidInstallments'] as num?)?.toDouble() ?? 0) *
              ((json['totalAmount'] as num).toDouble() /
                  (json['months'] as int).clamp(1, 999999)),
    description: json['description'] as String? ?? '',
  );

  Debt copyWith({
    String? name,
    String? category,
    String? subcategory,
    String? country,
    double? totalAmount,
    DateTime? startDate,
    int? months,
    double? paidAmount,
    String? description,
  }) {
    return Debt(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      country: country ?? this.country,
      totalAmount: totalAmount ?? this.totalAmount,
      startDate: startDate ?? this.startDate,
      months: months ?? this.months,
      paidAmount: paidAmount ?? this.paidAmount,
      description: description ?? this.description,
    );
  }
}
