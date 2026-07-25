/// Representa um par Ano/Mês.
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

  YearMonth addMonths(int n) {
    var y = year;
    var m = month + n;
    while (m > 12) {
      m -= 12;
      y++;
    }
    while (m < 1) {
      m += 12;
      y--;
    }
    return YearMonth(y, m);
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

/// Intervalo de período (inclusive), no estilo de seletores de analytics:
/// o usuário escolhe um mês/ano inicial e final, sem limite de anos.
class PeriodRange {
  final YearMonth start;
  final YearMonth end;

  const PeriodRange(this.start, this.end);

  factory PeriodRange.singleMonth(YearMonth ym) => PeriodRange(ym, ym);

  /// Últimos [n] meses, terminando no mês atual (inclusive) — estilo GA.
  factory PeriodRange.lastNMonths(int n, {YearMonth? endMonth}) {
    final end = endMonth ?? YearMonth.fromDate(DateTime.now());
    final start = end.addMonths(-(n - 1));
    return PeriodRange(start, end);
  }

  List<YearMonth> get months {
    final list = <YearMonth>[];
    var cursor = start;
    // Suporta intervalos "invertidos" trocando automaticamente.
    final s = start.compareTo(end) <= 0 ? start : end;
    final e = start.compareTo(end) <= 0 ? end : start;
    cursor = s;
    while (cursor.compareTo(e) <= 0) {
      list.add(cursor);
      cursor = cursor.next();
    }
    return list;
  }

  Set<YearMonth> get monthSet => months.toSet();

  int get monthCount => months.length;

  bool get isSingleMonth => start == end;

  /// Intervalo imediatamente anterior, com a mesma quantidade de meses —
  /// usado para comparações ("¿Estoy mejor o peor que el período anterior?").
  PeriodRange get previousEquivalent {
    final n = monthCount;
    final newEnd = start.previous();
    final newStart = newEnd.addMonths(-(n - 1));
    return PeriodRange(newStart, newEnd);
  }

  Map<String, dynamic> toJson() => {
    'startYear': start.year,
    'startMonth': start.month,
    'endYear': end.year,
    'endMonth': end.month,
  };

  factory PeriodRange.fromJson(Map<String, dynamic> json) => PeriodRange(
    YearMonth(json['startYear'] as int, json['startMonth'] as int),
    YearMonth(json['endYear'] as int, json['endMonth'] as int),
  );

  @override
  bool operator ==(Object other) =>
      other is PeriodRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
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

/// Rótulo amigável de um intervalo, ex: "Diciembre 2025" ou "Ago – Dic 2025".
String periodRangeLabel(PeriodRange r) {
  if (r.isSingleMonth) return monthLabel(r.start);
  if (r.start.year == r.end.year) {
    return '${monthShortEs[r.start.month]} – ${monthShortEs[r.end.month]} ${r.end.year}';
  }
  return '${monthShortLabel(r.start)} – ${monthShortLabel(r.end)}';
}

/// Versão bem curta do rótulo, usada quando o seletor de período precisa
/// compartilhar espaço com outros elementos (ex.: mesma fila dos KPIs).
String periodRangeShortLabel(PeriodRange r) {
  if (r.isSingleMonth) return monthShortLabel(r.start);
  if (r.start.year == r.end.year) {
    return '${monthShortEs[r.start.month]}–${monthShortEs[r.end.month]}';
  }
  return '${monthShortEs[r.start.month]}${r.start.year.toString().substring(2)}'
      '–${monthShortEs[r.end.month]}${r.end.year.toString().substring(2)}';
}
