import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/period.dart';
import '../widgets/common.dart';

class AnalisisScreen extends StatefulWidget {
  const AnalisisScreen({super.key});

  @override
  State<AnalisisScreen> createState() => _AnalisisScreenState();
}

class _AnalisisScreenState extends State<AnalisisScreen> {
  Set<String> _catFilter = {};
  Set<String> _countryFilter = {};
  TxNature? _naturaleza;

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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Análisis considera os meses selecionados no topo, mas com filtros próprios.
    final periods = state.selectedPeriods;
    var txns = state
        .txnsForPeriods(periods)
        .where((t) => t.type == TxType.gasto || t.type == TxType.deuda)
        .toList();

    if (_catFilter.isNotEmpty)
      txns = txns.where((t) => _catFilter.contains(t.category)).toList();
    if (_countryFilter.isNotEmpty)
      txns = txns.where((t) => _countryFilter.contains(t.country)).toList();
    if (_naturaleza != null)
      txns = txns.where((t) => t.nature == _naturaleza).toList();

    final allCategories = txns.map((t) => t.category).toSet().toList();
    final allCountries = state.countries;

    // Gráfico 1: gastos por categoria
    final Map<String, double> byCategory = {};
    for (final t in txns) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }
    final sortedCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalGastos = byCategory.values.fold(0.0, (s, v) => s + v);

    // Gráfico 2: gastos por categoria e país
    final Map<String, Map<String, double>> byCategoryCountry = {};
    for (final t in txns) {
      byCategoryCountry.putIfAbsent(t.category, () => {});
      byCategoryCountry[t.category]![t.country] =
          (byCategoryCountry[t.category]![t.country] ?? 0) + t.amount;
    }
    final countriesInData = txns.map((t) => t.country).toSet().toList();

    // Evolução mensal (ingresos vs gastos vs inversiones)
    final sortedPeriods = periods.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        SectionTitle(title: 'Filtros'),
        _FiltersRow(
          categories: allCategories.isEmpty
              ? byCategory.keys.toList()
              : state.expenseCategories.map((c) => c.name).toList(),
          countries: allCountries,
          selectedCats: _catFilter,
          selectedCountries: _countryFilter,
          naturaleza: _naturaleza,
          onCatsChanged: (v) => setState(() => _catFilter = v),
          onCountriesChanged: (v) => setState(() => _countryFilter = v),
          onNaturalezaChanged: (v) => setState(() => _naturaleza = v),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(title: 'Gastos por categoría'),
        SectionCard(
          child: sortedCats.isEmpty
              ? const SizedBox(
                  height: 120,
                  child: Center(child: Text('Sin datos para mostrar.')),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 42,
                          sections: List.generate(sortedCats.length, (i) {
                            final e = sortedCats[i];
                            final pct = totalGastos <= 0
                                ? 0
                                : (e.value / totalGastos * 100);
                            return PieChartSectionData(
                              value: e.value,
                              color: _palette[i % _palette.length],
                              title: '${pct.toStringAsFixed(0)}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            );
                          }),
                        ),
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
        SectionTitle(title: 'Gastos por categoría y país'),
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
        SectionTitle(title: 'Resumen automático'),
        SectionCard(
          child: _AutoSummary(
            state: state,
            periods: sortedPeriods,
            byCategory: byCategory,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(title: 'Evolución mensual'),
        SectionCard(
          child: sortedPeriods.length < 2
              ? const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      'Selecciona al menos 2 meses para ver la evolución.',
                    ),
                  ),
                )
              : SizedBox(
                  height: 220,
                  child: _EvolutionChart(state: state, periods: sortedPeriods),
                ),
        ),
      ],
    );
  }
}

class _FiltersRow extends StatelessWidget {
  final List<String> categories;
  final List<String> countries;
  final Set<String> selectedCats;
  final Set<String> selectedCountries;
  final TxNature? naturaleza;
  final ValueChanged<Set<String>> onCatsChanged;
  final ValueChanged<Set<String>> onCountriesChanged;
  final ValueChanged<TxNature?> onNaturalezaChanged;

  const _FiltersRow({
    required this.categories,
    required this.countries,
    required this.selectedCats,
    required this.selectedCountries,
    required this.naturaleza,
    required this.onCatsChanged,
    required this.onCountriesChanged,
    required this.onNaturalezaChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categoría',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: categories.map((c) {
            final sel = selectedCats.contains(c);
            return FilterChip(
              label: Text(c, style: const TextStyle(fontSize: 11.5)),
              selected: sel,
              onSelected: (_) {
                final next = {...selectedCats};
                sel ? next.remove(c) : next.add(c);
                onCatsChanged(next);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'País',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: countries.map((c) {
            final sel = selectedCountries.contains(c);
            return FilterChip(
              label: Text(c, style: const TextStyle(fontSize: 11.5)),
              selected: sel,
              onSelected: (_) {
                final next = {...selectedCountries};
                sel ? next.remove(c) : next.add(c);
                onCountriesChanged(next);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Naturaleza',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Todas', style: TextStyle(fontSize: 11.5)),
              selected: naturaleza == null,
              onSelected: (_) => onNaturalezaChanged(null),
            ),
            ChoiceChip(
              label: const Text('Fijo', style: TextStyle(fontSize: 11.5)),
              selected: naturaleza == TxNature.fijo,
              onSelected: (_) => onNaturalezaChanged(TxNature.fijo),
            ),
            ChoiceChip(
              label: const Text('Variable', style: TextStyle(fontSize: 11.5)),
              selected: naturaleza == TxNature.variable,
              onSelected: (_) => onNaturalezaChanged(TxNature.variable),
            ),
          ],
        ),
      ],
    );
  }
}

class _AutoSummary extends StatelessWidget {
  final AppState state;
  final List<YearMonth> periods;
  final Map<String, double> byCategory;
  const _AutoSummary({
    required this.state,
    required this.periods,
    required this.byCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (byCategory.isEmpty || periods.isEmpty) {
      return const Text(
        'No hay suficientes datos para generar un resumen automático.',
      );
    }
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    final total = byCategory.values.fold(0.0, (s, v) => s + v);
    final pctTop = total <= 0 ? 0 : (top.value / total * 100);

    final countriesInPeriod = state
        .txnsForPeriods(periods.toSet())
        .map((t) => t.country)
        .toSet()
        .toList();
    String countryPhrase = '';
    if (countriesInPeriod.length == 1) {
      countryPhrase =
          'El país con mayor concentración de gastos es ${countriesInPeriod.first}. ';
    } else if (countriesInPeriod.length > 1) {
      countryPhrase =
          'Se registran gastos en ${countriesInPeriod.length} países (${countriesInPeriod.join(', ')}). ';
    }

    final n = periods.length;
    final avgIngresos = state.totalIngresos / n;
    final avgGastos = state.totalGastosYDeudas / n;
    final margen = avgIngresos - avgGastos;
    final margenPhrase = margen >= 0
        ? 'Estás ${formatUsd(margen, decimals: false)} por encima de tus gastos en promedio mensual, lo que representa una margen saludable para invertir.'
        : 'Estás ${formatUsd(-margen, decimals: false)} por debajo de tus ingresos en promedio mensual; conviene revisar los gastos variables.';

    final periodLabel = n == 1
        ? monthLabel(periods.first)
        : 'los últimos $n meses';

    return Text(
      'En $periodLabel, tus mayores gastos fueron con ${top.key} (${formatUsd(top.value, decimals: false)}), representando ${pctTop.toStringAsFixed(0)}% del total de salidas analizadas. '
      '$countryPhrase$margenPhrase',
      style: const TextStyle(fontSize: 13, height: 1.5),
    );
  }
}

class _EvolutionChart extends StatelessWidget {
  final AppState state;
  final List<YearMonth> periods;
  const _EvolutionChart({required this.state, required this.periods});

  @override
  Widget build(BuildContext context) {
    final ingresos = <FlSpot>[];
    final gastos = <FlSpot>[];
    final inversiones = <FlSpot>[];

    for (int i = 0; i < periods.length; i++) {
      final p = periods[i];
      final txns = state.txnsForPeriods({p});
      final ing = txns
          .where((t) => t.type == TxType.ingreso)
          .fold(0.0, (s, t) => s + t.amount);
      final gas = txns
          .where((t) => t.type == TxType.gasto || t.type == TxType.deuda)
          .fold(0.0, (s, t) => s + t.amount);
      final inv = txns
          .where((t) => t.type == TxType.inversion)
          .fold(0.0, (s, t) => s + t.amount);
      ingresos.add(FlSpot(i.toDouble(), ing));
      gastos.add(FlSpot(i.toDouble(), gas));
      inversiones.add(FlSpot(i.toDouble(), inv));
    }

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= periods.length)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          monthShortLabel(periods[idx]),
                          style: const TextStyle(fontSize: 9.5),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: ingresos,
                  isCurved: true,
                  color: AppColors.ingreso,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
                LineChartBarData(
                  spots: gastos,
                  isCurved: true,
                  color: AppColors.gasto,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
                LineChartBarData(
                  spots: inversiones,
                  isCurved: true,
                  color: AppColors.inversion,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          children: const [
            _LegendDot(color: AppColors.ingreso, label: 'Ingresos'),
            _LegendDot(color: AppColors.gasto, label: 'Gastos'),
            _LegendDot(color: AppColors.inversion, label: 'Inversiones'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }
}
