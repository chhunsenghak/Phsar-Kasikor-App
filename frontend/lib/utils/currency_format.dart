/// Formats an amount in its own currency — KHR as a thousands-grouped
/// integer with a trailing ៛, everything else (USD) as $X,XXX.XX. Never
/// mix amounts from different currencies before calling this: there's no
/// exchange rate anywhere in this app to convert between them.
String formatCurrency(num amount, [String currency = 'USD']) {
  if (currency == 'KHR') {
    final String val = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '$val ៛';
  }
  final parts = amount.toStringAsFixed(2).split('.');
  final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  String mathFunc(Match match) => '${match[1]},';
  final formattedInt = parts[0].replaceAllMapped(reg, mathFunc);
  return '\$$formattedInt.${parts[1]}';
}
