import '../models/enums.dart';
import '../models/transaction.dart';
import '../models/budget_item.dart';
import '../models/goal.dart';
import '../models/debt.dart';
import '../models/taxonomy.dart';
import '../models/insight.dart';
import '../utils/period.dart';
import '../utils/formatters.dart';

/// Motor de inteligência financeira do Prospera: transforma números em
/// linguagem natural. Substitui tabelas por interpretações, sempre que
/// possible, seguindo o mandato "menos informação, más inteligencia".
///
/// Cada método analisa um aspecto dos dados do período selecionado e — se
/// houver algo relevante para dizer — produz um [Insight]. Se não houver
/// nada relevante, simplesmente não gera nada (menos é mais).
class InsightsEngine {
  final List<Txn> allTxns;
  final List<BudgetItem> allBudgets;
  final List<CategoryDef> expenseCategories;
  final List<InvestmentGoal> goals;
  final List<Debt> debts;

  InsightsEngine({
    required this.allTxns,
    required this.allBudgets,
    required this.expenseCategories,
    required this.goals,
    required this.debts,
  });

  List<Txn> _txnsFor(PeriodRange r) {
    final set = r.monthSet;
    return allTxns
        .where((t) => set.contains(YearMonth(t.year, t.month)) && !t.isPending)
        .toList();
  }

  List<BudgetItem> _budgetsFor(PeriodRange r) {
    final set = r.monthSet;
    return allBudgets
        .where((b) => set.contains(YearMonth(b.year, b.month)))
        .toList();
  }

  double _sumByType(List<Txn> txns, TxType type) =>
      txns.where((t) => t.type == type).fold(0.0, (s, t) => s + t.amount);

  /// Inversión NETA (aportes - rescates) — un rescate devuelve dinero al
  /// saldo disponible, por lo que debe restar de la inversión total en vez
  /// de sumar (misma semántica que [AppState.totalInversiones]).
  double _netInversion(List<Txn> txns) {
    final aportes = txns
        .where((t) => t.type == TxType.inversion && !t.isWithdrawal)
        .fold(0.0, (s, t) => s + t.amount);
    final rescates = txns
        .where((t) => t.type == TxType.inversion && t.isWithdrawal)
        .fold(0.0, (s, t) => s + t.amount);
    return aportes - rescates;
  }

  Controllability _controllabilityOf(String category, String subcategory) {
    final match = expenseCategories.where((c) => c.name == category);
    if (match.isEmpty) return Controllability.semiControlable;
    return match.first.controllabilityFor(subcategory);
  }

  /// Gera a lista completa de insights para o período selecionado,
  /// comparando com o período anterior equivalente quando possível.
  ///
  /// [upcomingDueItems] — quando informado, deve ser o resultado de
  /// [AppState.upcomingDue] (fonte única de verdade, com lógica de
  /// cobertura acumulada para Deudas/Objetivos) e substitui completamente
  /// a lógica própria deste motor para o item "Deudas próximas a vencer" —
  /// evita que o Resumo Inteligente e a lista "Próximos vencimientos"
  /// mostrem informações divergentes sobre o mesmo dado.
  List<Insight> generate(
    PeriodRange current, {
    List<BudgetItem>? upcomingDueItems,
  }) {
    final insights = <Insight>[];
    final txns = _txnsFor(current);
    final prevTxns = _txnsFor(current.previousEquivalent);
    final budgets = _budgetsFor(current);

    final ingresos = _sumByType(txns, TxType.ingreso);
    final gastos =
        _sumByType(txns, TxType.gasto) + _sumByType(txns, TxType.deuda);
    final inversiones = _netInversion(txns);
    final balance = ingresos - gastos - inversiones;

    final prevIngresos = _sumByType(prevTxns, TxType.ingreso);
    final prevGastos =
        _sumByType(prevTxns, TxType.gasto) + _sumByType(prevTxns, TxType.deuda);
    final prevBalance = prevIngresos - prevGastos - _netInversion(prevTxns);

    final hasPrevData = prevTxns.isNotEmpty;

    // 1) Comparación general con el período anterior.
    if (hasPrevData) {
      final delta = balance - prevBalance;
      if (delta.abs() >= 1) {
        if (delta > 0) {
          insights.add(
            Insight(
              text:
                  'Estás mejor que en el período anterior: tu saldo mejoró en ${formatUsd(delta, decimals: false)}.',
              tone: InsightTone.positivo,
              iconKey: 'trending_up',
            ),
          );
        } else {
          insights.add(
            Insight(
              text:
                  'Tu saldo empeoró ${formatUsd(-delta, decimals: false)} respecto al período anterior. Vale la pena revisar tus gastos.',
              tone: InsightTone.alerta,
              iconKey: 'trending_down',
            ),
          );
        }
      }
    }

    // 2) Ahorro o déficit del período actual.
    if (balance > 0) {
      insights.add(
        Insight(
          text:
              'Ahorraste ${formatUsd(balance, decimals: false)} en este período.',
          tone: InsightTone.positivo,
          iconKey: 'savings',
        ),
      );
    } else if (balance < 0) {
      insights.add(
        Insight(
          text:
              'Gastaste ${formatUsd(-balance, decimals: false)} más de lo que ingresó en este período.',
          tone: InsightTone.peligro,
          iconKey: 'warning',
        ),
      );
    }

    // 3) Mayor gasto por categoría (con continuidad respecto al período anterior).
    final byCategory = <String, double>{};
    for (final t in txns.where(
      (t) => t.type == TxType.gasto || t.type == TxType.deuda,
    )) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }
    if (byCategory.isNotEmpty) {
      final sorted = byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;

      final prevByCategory = <String, double>{};
      for (final t in prevTxns.where(
        (t) => t.type == TxType.gasto || t.type == TxType.deuda,
      )) {
        prevByCategory[t.category] =
            (prevByCategory[t.category] ?? 0) + t.amount;
      }
      final prevTop = prevByCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final continues = prevTop.isNotEmpty && prevTop.first.key == top.key;

      insights.add(
        Insight(
          text: continues
              ? 'Tu mayor gasto sigue siendo ${top.key} (${formatUsd(top.value, decimals: false)}).'
              : 'Tu mayor gasto en este período fue ${top.key} (${formatUsd(top.value, decimals: false)}).',
          tone: InsightTone.neutro,
          iconKey: 'trending_down',
        ),
      );
    }

    // 4) Cuánto se puede invertir sin comprometer el presupuesto.
    if (balance > 0) {
      final investible = balance * 0.6;
      if (investible >= 10) {
        insights.add(
          Insight(
            text:
                'Puedes invertir aproximadamente ${formatUsd(investible, decimals: false)} sin comprometer tu presupuesto.',
            tone: InsightTone.positivo,
            iconKey: 'flag',
          ),
        );
      }
    }

    // 5) Presupuestos excedidos (con recomendación según controlabilidad).
    //
    // BUGFIX: [b.planned] es el valor planificado de UN mes específico
    // (b.year/b.month), pero [txns] puede contener varios meses cuando el
    // período seleccionado abarca más de uno. Comparar el total de TODOS
    // esos meses contra el presupuesto de un solo mes inflaba (o
    // duplicaba, un mensaje por cada BudgetItem del rango) el "excedido"
    // mostrado — causa raíz del mensaje "fantasma" de presupuesto
    // superado que no correspondía a la realidad de ningún mes concreto.
    // Solución: acotar el realizado al MISMO mes/año del ítem, y generar
    // como máximo un insight por categoría+subcategoría (evita repetir el
    // mismo aviso una vez por cada mes del rango).
    final excededSeen = <String>{};
    for (final b in budgets) {
      final key = '${b.category}|${b.subcategory}';
      if (excededSeen.contains(key)) continue;
      final realizado = txns
          .where(
            (t) =>
                (t.type == TxType.gasto || t.type == TxType.deuda) &&
                t.category == b.category &&
                t.subcategory == b.subcategory &&
                t.year == b.year &&
                t.month == b.month,
          )
          .fold(0.0, (s, t) => s + t.amount);
      if (b.planned > 0 && realizado > b.planned) {
        excededSeen.add(key);
        final exceso = realizado - b.planned;
        final controllability = _controllabilityOf(b.category, b.subcategory);
        String recomendacion;
        switch (controllability) {
          case Controllability.controlable:
            recomendacion =
                'Es un gasto controlable: es posible economizar aproximadamente ${formatUsd(exceso * 0.5, decimals: false)} ajustando tus hábitos en ${b.subcategory}.';
            break;
          case Controllability.semiControlable:
            recomendacion =
                'Es un gasto parcialmente controlable. Vale la pena revisar los planes o contratos relacionados con ${b.subcategory}.';
            break;
          case Controllability.pocoControlable:
            recomendacion =
                'Como es un gasto poco controlable, recomendamos aumentar tu presupuesto de ${b.subcategory} para el próximo mes.';
            break;
        }
        insights.add(
          Insight(
            text:
                'Superaste tu presupuesto de ${b.subcategory} en ${formatUsd(exceso, decimals: false)}. $recomendacion',
            tone: Controllability.pocoControlable == controllability
                ? InsightTone.alerta
                : InsightTone.alerta,
            iconKey: 'warning',
          ),
        );
      }
    }

    // 6) Deudas/Objetivos próximos a vencer — usa EXCLUSIVAMENTE la lista
    // ya calculada por [AppState.upcomingDue] (fuente única de verdad con
    // cobertura acumulada), en vez de recalcular con lógica propia. Así se
    // evita que este mensaje mencione una cuota/aporte que la lista
    // "Próximos vencimientos" ya considera cubierta (pagos adelantados o
    // en un solo monto que cubre varios meses).
    if (upcomingDueItems != null) {
      final now = DateTime.now();
      final debtById = {for (final d in debts) d.id: d};
      final goalById = {for (final g in goals) g.id: g};
      for (final b in upcomingDueItems) {
        if (b.dueDate == null) continue;
        final days = b.dueDate!.difference(now).inDays;
        if (b.linkedDebtId != null) {
          final debt = debtById[b.linkedDebtId];
          if (debt == null) continue;
          insights.add(
            Insight(
              text:
                  'La cuota de "${debt.name}" (${formatUsd(b.planned, decimals: false)}) vence en ${days <= 0 ? "hoy" : "$days día(s)"}.',
              tone: InsightTone.alerta,
              iconKey: 'account_balance',
            ),
          );
        } else if (b.linkedGoalId != null) {
          final goal = goalById[b.linkedGoalId];
          if (goal == null) continue;
          insights.add(
            Insight(
              text:
                  'Para alcanzar "${goal.name}" a tiempo, aporta ${formatUsd(b.planned, decimals: false)} — vence en ${days <= 0 ? "hoy" : "$days día(s)"}.',
              tone: InsightTone.neutro,
              iconKey: 'flag',
            ),
          );
        }
      }
    }

    return insights;
  }

  /// Sugestão automática de orçamento do próximo mês, com base na média
  /// histórica realizada por categoria+subcategoria nos últimos [months] meses.
  List<BudgetItem> suggestNextMonthBudget({
    required YearMonth targetMonth,
    int lookbackMonths = 3,
  }) {
    final lookback = PeriodRange(
      targetMonth.previous().addMonths(-(lookbackMonths - 1)),
      targetMonth.previous(),
    );
    final txns = _txnsFor(lookback);
    final Map<String, List<double>> amounts = {};
    final Map<String, String> countryOf = {};
    for (final t in txns.where(
      (t) => t.type == TxType.gasto || t.type == TxType.deuda,
    )) {
      final key = '${t.category}|${t.subcategory}';
      amounts.putIfAbsent(key, () => []).add(t.amount);
      countryOf[key] = t.country;
    }
    final suggestions = <BudgetItem>[];
    amounts.forEach((key, values) {
      final parts = key.split('|');
      final avg = values.fold(0.0, (s, v) => s + v) / lookbackMonths;
      if (avg <= 0) return;
      suggestions.add(
        BudgetItem(
          id: 'suggestion_$key',
          month: targetMonth.month,
          year: targetMonth.year,
          category: parts[0],
          subcategory: parts.length > 1 ? parts[1] : '',
          country: countryOf[key] ?? '',
          planned: double.parse(avg.toStringAsFixed(2)),
          autoSuggested: true,
        ),
      );
    });
    return suggestions;
  }
}
