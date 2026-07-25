/// Representa um par Ano/Mês, usado para os filtros de período (múltipla escolha).
class YearMonth implements Comparable<YearMonth> {
  final int year;
  final int month; // 1-12

  const YearMonth(this.year, this.month);

  factory YearMonth.fromDate(DateTime d) => YearMonth(d.year, d.month);

  YearMonth next() {
    if (month == 12) return YearMonth(year + 1, 1);
    return YearMonth(year, month + 1);
  }

  YearMonth previous() {
    if (month == 1) return YearMonth(year - 1, 12);
    return YearMonth(year, month - 1);
  }

  DateTime get firstDay => DateTime(year, month, 1);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => year * 100 + month;

  @override
  int compareTo(YearMonth other) {
    if (year != other.year) return year.compareTo(other.year);
    return month.compareTo(other.month);
  }

  @override
  String toString() => '$year-$month';
}

const List<String> monthNamesEs = [
  '',
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const List<String> monthShortEs = [
  '',
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

String monthLabel(YearMonth ym) => '${monthNamesEs[ym.month]} ${ym.year}';
String monthShortLabel(YearMonth ym) => '${monthShortEs[ym.month]} ${ym.year}';
