import 'package:intl/intl.dart';
import 'period.dart';

final NumberFormat _currencyFmt = NumberFormat.currency(
  locale: 'en_US',
  symbol: '\$',
  decimalDigits: 2,
);
final NumberFormat _currencyFmtNoDecimals = NumberFormat.currency(
  locale: 'en_US',
  symbol: '\$',
  decimalDigits: 0,
);

String formatUsd(double value, {bool decimals = true}) {
  final formatter = decimals ? _currencyFmt : _currencyFmtNoDecimals;
  return formatter.format(value);
}

String formatUsdSigned(double value) {
  final abs = formatUsd(value.abs());
  if (value > 0) return '+$abs';
  if (value < 0) return '-$abs';
  return abs;
}

/// Formatação de datas sem depender de dados de locale do pacote intl
/// (evita necessidade de inicialização de locale 'es').
String formatDayMonth(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${monthShortEs[d.month]}';

String formatFullDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
