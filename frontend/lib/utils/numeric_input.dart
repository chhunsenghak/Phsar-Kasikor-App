/// Parses a user-entered number that may use Khmer digits (០-៩) or a comma
/// as the decimal separator, returning null if the result isn't a valid
/// number.
double? parseNumericInput(String raw) {
  const khmerDigits = '០១២៣៤៥៦៧៨៩';
  final buffer = StringBuffer();
  for (final ch in raw.trim().split('')) {
    final khmerIndex = khmerDigits.indexOf(ch);
    if (khmerIndex != -1) {
      buffer.write(khmerIndex);
    } else if (ch == ',') {
      buffer.write('.');
    } else {
      buffer.write(ch);
    }
  }
  return double.tryParse(buffer.toString());
}
