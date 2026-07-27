import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/taxonomy.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/period.dart';
import '../widgets/common.dart';
import '../widgets/filter_bar.dart';
import '../widgets/period_selector.dart';

/// Filtro de tipo de movimiento para los gráficos de esta pantalla — mismo
/// patrón visual de "chips" ya usado en Transações/Planificación, pero
/// coloreado según el color semántico de cada [TxType] (en vez de un único
/// color de acento), lo que refuerza la identidad visual de Análisis frente
/// a esas otras dos pestañas sin romper la paleta general del app.
enum _AnalisisFilter { gastos, ingresos, inversiones, deudas, todos }

/// Aba Análisis: responde las preguntas "¿Dónde gasto/recibo/invierto más?"
/// y su equivalente por país, con un filtro de tipo de movimiento y un
/// selector de período — seguidas de un resumen automático con lenguaje de
/// tendencia.
class AnalisisScreen extends StatefulWidget {
  const AnalisisScreen({super.key});

  @override
  State<AnalisisScreen> createState() => _AnalisisScreenState();
}

class _AnalisisScreenState extends State<AnalisisScreen> {
  _AnalisisFilter _filter = _AnalisisFilter.gastos;

  // ------- Filtros avançados (categoria/subcategoria/país) -------
  String? _advCategory;
  String? _advSubcategory;
  String? _advCountry;

  bool get _hasAdvancedFilters =>
      _advCategory != null || _advSubcategory != null || _advCountry != null;

  void _clearAdvancedFilters() {
    _advCategory = null;
    _advSubcategory = null;
    _advCountry = null;
  }

  /// Painel de "filtros avançados" — segue exatamente o mesmo padrão visual
  /// e estrutural do painel de Planificación (AdvancedFilterLabel + Wrap de
  /// ChoiceChip, com opção "Todas/Todos" primeiro em cada grupo).
  void _openAdvancedFilters(BuildContext context, AppState state) {
    final categories = state.expenseCategories;
    final countries = state.countries;
    showAdvancedFiltersSheet(
      context,
      title: 'Filtros avanzados',
      onClear: _clearAdvancedFilters,
      onApply: () => setState(() {}),
      builder: (ctx, setModalState) {
        return StatefulBuilder(
          builder: (ctx, localSet) {
            final subOptions = _advCategory == null
                ? <String>[]
                : (categories
                          .where((c) => c.name == _advCategory)
                          .map((c) => c.subcategories)
                          .firstOrNull ??
                      const <String>[]);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdvancedFilterLabel('Categoría'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: _advCategory == null,
                      onSelected: (_) {
                        setState(() {
                          _advCategory = null;
                          _advSubcategory = null;
                        });
                        localSet(() {});
                      },
                    ),
                    ...categories.map(
                      (c) => ChoiceChip(
                        label: Text(c.name),
                        selected: _advCategory == c.name,
                        onSelected: (_) {
                          setState(() {
                            _advCategory = c.name;
                            _advSubcategory = null;
                          });
                          localSet(() {});
                        },
                      ),
                    ),
                  ],
                ),
                if (subOptions.isNotEmpty) ...[
                  const AdvancedFilterLabel('Subcategoría'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('Todas'),
                        selected: _advSubcategory == null,
                        onSelected: (_) {
                          setState(() => _advSubcategory = null);
                          localSet(() {});
                        },
                      ),
                      ...subOptions.map(
                        (s) => ChoiceChip(
                          label: Text(s),
                          selected: _advSubcategory == s,
                          onSelected: (_) {
                            setState(() => _advSubcategory = s);
                            localSet(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const AdvancedFilterLabel('País'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _advCountry == null,
                      onSelected: (_) {
                        setState(() => _advCountry = null);
                        localSet(() {});
                      },
                    ),
                    ...countries.map(
                      (c) => ChoiceChip(
                        label: Text(c),
                        selected: _advCountry == c,
                        onSelected: (_) {
                          setState(() => _advCountry = c);
                          localSet(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  static const _palette = [
    Color(0xFFFF5252),
    Color(0xFFFF8A65),
    Color(0xFFFFB300),
    Color(0xFF448AFF),
    Color(0xFF00C853),
    Color(0xFFAB47BC),
    Color(0xFF26C6DA),
    Color(0xFFEC407A),
  ];

  /// Conjunto de tipos incluidos por cada opción del filtro. "Gastos"
  /// mantiene el comportamiento original de la pantalla (gasto + cuota de
  /// deuda contados juntos), evitando romper el análisis por defecto.
  Set<TxType> get _typesForFilter {
    switch (_filter) {
      case _AnalisisFilter.gastos:
        return {TxType.gasto, TxType.deuda};
      case _AnalisisFilter.ingresos:
        return {TxType.ingreso};
      case _AnalisisFilter.inversiones:
        return {TxType.inversion};
      case _AnalisisFilter.deudas:
        return {TxType.deuda};
      case _AnalisisFilter.todos:
        return {TxType.ingreso, TxType.gasto, TxType.inversion, TxType.deuda};
    }
  }

  String get _sectionTitle1 {
    switch (_filter) {
      case _AnalisisFilter.gastos:
        return '¿Dónde gasto más?';
      case _AnalisisFilter.ingresos:
        return '¿De dónde viene tu dinero?';
      case _AnalisisFilter.inversiones:
        return '¿Dónde inviertes más?';
      case _AnalisisFilter.deudas:
        return '¿Cuáles son tus mayores deudas?';
      case _AnalisisFilter.todos:
        return '¿Dónde se concentra tu dinero?';
    }
  }

  String get _sectionTitle2 {
    switch (_filter) {
      case _AnalisisFilter.gastos:
        return '¿Dónde gasto más por país?';
      case _AnalisisFilter.ingresos:
        return '¿De dónde viene tu dinero por país?';
      case _AnalisisFilter.inversiones:
        return '¿Dónde inviertes más por país?';
      case _AnalisisFilter.deudas:
        return '¿Dónde tienes más deudas por país?';
      case _AnalisisFilter.todos:
        return '¿Cómo se distribuye por país?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final range = state.selectedRange;
    final types = _typesForFilter;
    var txns = state
        .txnsForRange(range)
        .where((t) => types.contains(t.type))
        .toList();
    if (_hasAdvancedFilters) {
      txns = txns.where((t) {
        if (_advCategory != null && t.category != _advCategory) return false;
        if (_advSubcategory != null && t.subcategory != _advSubcategory) {
          return false;
        }
        if (_advCountry != null && t.country != _advCountry) return false;
        return true;
      }).toList();
    }
    // El Resumen automático más abajo siempre analiza gasto+deuda —
    // independiente del filtro elegido arriba — porque su narrativa de
    // tendencia ("tu mayor gasto fue...") no tiene sentido si se mezclan
    // otros tipos de movimiento.
    final resumenTxns = state
        .txnsForRange(range)
        .where((t) => t.type == TxType.gasto || t.type == TxType.deuda)
        .toList();
    final Map<String, double> byCategoryResumen = {};
    for (final t in resumenTxns) {
      byCategoryResumen[t.category] =
          (byCategoryResumen[t.category] ?? 0) + t.amount;
    }

    // Gráfico 1: gastos por categoría (mayor a menor).
    final Map<String, double> byCategory = {};
    for (final t in txns) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }
    final sortedCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalGastos = byCategory.values.fold(0.0, (s, v) => s + v);

    // Gráfico 2: gastos por categoría y país.
    final Map<String, Map<String, double>> byCategoryCountry = {};
    for (final t in txns) {
      byCategoryCountry.putIfAbsent(t.category, () => {});
      byCategoryCountry[t.category]![t.country] =
          (byCategoryCountry[t.category]![t.country] ?? 0) + t.amount;
    }
    final countriesInData = txns.map((t) => t.country).toSet().toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        ScreenHeader(
          icon: Icons.bar_chart_rounded,
          iconColor: AppColors.inversion,
          title: 'Análisis',
          subtitle:
              'Comprende tus patrones financieros y toma mejores decisiones.',
          trailing: const PeriodSelector(inline: true),
        ),
        SegmentedFilterBar<_AnalisisFilter>(
          options: const [
            FilterOption(_AnalisisFilter.gastos, 'Gastos'),
            FilterOption(_AnalisisFilter.ingresos, 'Ingresos'),
            FilterOption(_AnalisisFilter.inversiones, 'Inversiones'),
            FilterOption(_AnalisisFilter.deudas, 'Deudas'),
            FilterOption(_AnalisisFilter.todos, 'Todos'),
          ],
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f),
          onAdvancedTap: () => _openAdvancedFilters(context, state),
          advancedActive: _hasAdvancedFilters,
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionTitle(title: _sectionTitle1),
        SectionCard(
          child: sortedCats.isEmpty
              ? const SizedBox(
                  height: 120,
                  child: Center(child: Text('Sin datos para mostrar.')),
                )
              : Column(
                  children: [
                    // Gráfico de barras (valores absolutos por categoría) y
                    // gráfico de pizza (mismos datos en %) lado a lado, para
                    // comparar magnitud y proporción de un solo vistazo.
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 190,
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: (sortedCats.isEmpty
                                      ? 10
                                      : sortedCats.first.value * 1.2 + 5),
                                  barTouchData: BarTouchData(enabled: true),
                                  titlesData: FlTitlesData(
                                    leftTitles: const AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 34,
                                      ),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 28,
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.toInt();
                                          if (idx < 0 ||
                                              idx >= sortedCats.length) {
                                            return const SizedBox.shrink();
                                          }
                                          final name = sortedCats[idx].key;
                                          final short = name.length > 6
                                              ? '${name.substring(0, 6)}…'
                                              : name;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              short,
                                              style: const TextStyle(
                                                fontSize: 8.5,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  gridData: const FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: List.generate(sortedCats.length, (
                                    i,
                                  ) {
                                    final e = sortedCats[i];
                                    return BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: e.value,
                                          color: _palette[i % _palette.length],
                                          width: 14,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 160,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 30,
                                  sections: List.generate(sortedCats.length, (
                                    i,
                                  ) {
                                    final e = sortedCats[i];
                                    final pct = totalGastos <= 0
                                        ? 0
                                        : (e.value / totalGastos * 100);
                                    return PieChartSectionData(
                                      value: e.value,
                                      color: _palette[i % _palette.length],
                                      title: '${pct.toStringAsFixed(0)}%',
                                      radius: 46,
                                      titleStyle: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...List.generate(sortedCats.length, (i) {
                      final e = sortedCats[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _palette[i % _palette.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            Text(
                              formatUsd(e.value, decimals: false),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(title: _sectionTitle2),
        SectionCard(
          child: byCategoryCountry.isEmpty
              ? const SizedBox(
                  height: 120,
                  child: Center(child: Text('Sin datos para mostrar.')),
                )
              : SizedBox(
                  height: 240,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          (byCategoryCountry.values
                                  .map(
                                    (m) => m.values.fold(0.0, (s, v) => s + v),
                                  )
                                  .fold(0.0, (a, b) => a > b ? a : b)) *
                              1.2 +
                          10,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final keys = byCategoryCountry.keys.toList();
                              final idx = value.toInt();
                              if (idx < 0 || idx >= keys.length)
                                return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  keys[idx],
                                  style: const TextStyle(fontSize: 9.5),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(byCategoryCountry.length, (i) {
                        final cat = byCategoryCountry.keys.elementAt(i);
                        final countryMap = byCategoryCountry[cat]!;
                        return BarChartGroupData(
                          x: i,
                          barRods: List.generate(countriesInData.length, (j) {
                            final country = countriesInData[j];
                            return BarChartRodData(
                              toY: countryMap[country] ?? 0,
                              color: _palette[j % _palette.length],
                              width: 14,
                              borderRadius: BorderRadius.circular(3),
                            );
                          }),
                        );
                      }),
                    ),
                  ),
                ),
        ),
        if (countriesInData.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            children: List.generate(countriesInData.length, (j) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    color: _palette[j % _palette.length],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    countriesInData[j],
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ],
              );
            }),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(title: 'Resumen'),
        SectionCard(
          child: _AutoSummary(
            state: state,
            range: range,
            byCategory: byCategoryResumen,
          ),
        ),
      ],
    );
  }
}

class _AutoSummary extends StatelessWidget {
  final AppState state;
  final PeriodRange range;
  final Map<String, double> byCategory;
  const _AutoSummary({
    required this.state,
    required this.range,
    required this.byCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (byCategory.isEmpty) {
      return const Text(
        'No hay suficientes datos para generar un resumen automático.',
      );
    }
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    final total = byCategory.values.fold(0.0, (s, v) => s + v);
    final pctTop = total <= 0 ? 0 : (top.value / total * 100);

    final txns = state.txnsForRange(range);
    final countriesInPeriod = txns.map((t) => t.country).toSet().toList();
    String countryPhrase = '';
    if (countriesInPeriod.length == 1) {
      countryPhrase =
          'El país con mayor concentración de gastos es ${countriesInPeriod.first}. ';
    } else if (countriesInPeriod.length > 1) {
      // Descubre el país con mayor gasto total.
      final Map<String, double> byCountry = {};
      for (final t in txns.where(
        (t) => t.type == TxType.gasto || t.type == TxType.deuda,
      )) {
        byCountry[t.country] = (byCountry[t.country] ?? 0) + t.amount;
      }
      final topCountry = byCountry.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (topCountry.isNotEmpty) {
        countryPhrase =
            'El país con mayor volumen de gastos fue ${topCountry.first.key}. ';
      }
    }

    // Comparación con el período anterior equivalente (tendencia).
    final prevTxns = state.txnsForRange(range.previousEquivalent);
    final prevGastos = prevTxns
        .where((t) => t.type == TxType.gasto || t.type == TxType.deuda)
        .fold(0.0, (s, t) => s + t.amount);
    // Inversión NETA (aportes - rescates): un rescate no debe contarse como
    // "inversión hecha", ya que representa dinero que volvió al saldo
    // disponible del usuario (misma semántica que AppState.totalInversiones).
    double netInversion(List<Txn> list) {
      final aportes = list
          .where((t) => t.type == TxType.inversion && !t.isWithdrawal)
          .fold(0.0, (s, t) => s + t.amount);
      final rescates = list
          .where((t) => t.type == TxType.inversion && t.isWithdrawal)
          .fold(0.0, (s, t) => s + t.amount);
      return aportes - rescates;
    }

    final invActual = netInversion(txns);
    final invPrev = netInversion(prevTxns);

    String growthPhrase = '';
    if (total > 0 && prevGastos > 0) {
      final growth = ((total - prevGastos) / prevGastos) * 100;
      if (growth.abs() >= 3) {
        growthPhrase = growth > 0
            ? 'Tus gastos crecieron ${growth.toStringAsFixed(0)}% respecto al período anterior. '
            : 'Tus gastos cayeron ${growth.abs().toStringAsFixed(0)}% respecto al período anterior. ';
      } else {
        growthPhrase =
            'Tus gastos se mantuvieron estables respecto al período anterior. ';
      }
    }

    // Evolución de las inversiones: cubre todos los escenarios posibles
    // (primera inversión, sin inversión, crecimiento, caída o estabilidad)
    // para que el usuario nunca tenga que interpretar el número por sí solo.
    String invPhrase;
    if (invActual <= 0 && invPrev <= 0) {
      invPhrase = 'Aún no registraste inversiones en este período. ';
    } else if (invPrev <= 0 && invActual > 0) {
      invPhrase =
          'Comenzaste a invertir en este período (${formatUsd(invActual, decimals: false)}), algo que no hacías en el período anterior. ';
    } else if (invActual <= 0 && invPrev > 0) {
      invPhrase =
          'Dejaste de invertir en este período, después de haber invertido ${formatUsd(invPrev, decimals: false)} en el período anterior. ';
    } else {
      final growth = ((invActual - invPrev) / invPrev) * 100;
      if (growth.abs() >= 3) {
        invPhrase = growth > 0
            ? 'Tus inversiones crecieron ${growth.toStringAsFixed(0)}% respecto al período anterior. '
            : 'Tus inversiones cayeron ${growth.abs().toStringAsFixed(0)}% respecto al período anterior. ';
      } else {
        invPhrase = 'Tus inversiones se mantuvieron estables. ';
      }
    }

    // Oportunidades de ahorro: prioriza categorías controlables (donde el
    // usuario tiene margen real de decisión) con mayor peso en el total,
    // en lugar de simplemente repetir la categoría más grande otra vez.
    String savingsPhrase = '';
    final controllableEntries = sorted.where((e) {
      final cat = state.expenseCategories.firstWhere(
        (c) => c.name == e.key,
        orElse: () => CategoryDef(name: e.key, subcategories: const []),
      );
      return cat.controllabilityFor(null) == Controllability.controlable;
    }).toList();
    if (controllableEntries.isNotEmpty) {
      final op = controllableEntries.first;
      final pctOp = total <= 0 ? 0 : (op.value / total * 100);
      if (pctOp >= 10) {
        savingsPhrase =
            'Tu mayor oportunidad de ahorro está en "${op.key}" '
            '(${formatUsd(op.value, decimals: false)}, ${pctOp.toStringAsFixed(0)}% del total): '
            'es un gasto que sí puedes controlar. ';
      }
    }
    if (savingsPhrase.isEmpty && pctTop >= 30) {
      savingsPhrase =
          'Como "${top.key}" concentra ${pctTop.toStringAsFixed(0)}% de tus gastos, '
          'reducirlo aunque sea un poco tendría el mayor impacto en tu balance. ';
    }

    final periodLabel = periodRangeLabel(range);

    return Text(
      'En $periodLabel, tu mayor gasto fue ${top.key} (${formatUsd(top.value, decimals: false)}), '
      'representando ${pctTop.toStringAsFixed(0)}% del total analizado. '
      '$countryPhrase$growthPhrase$savingsPhrase$invPhrase',
      style: const TextStyle(fontSize: 13, height: 1.5),
    );
  }
}
