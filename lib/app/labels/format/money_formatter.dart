abstract final class MoneyFormatter {
  static String compact(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  static String fixed(double amount) => amount.toStringAsFixed(2);

  static String fixedMicros(int micros, {int fractionDigits = 2}) {
    if (micros < 0 || fractionDigits < 0 || fractionDigits > 6) {
      throw ArgumentError('Invalid fixed-point format parameters');
    }
    var divisor = 1;
    for (var i = fractionDigits; i < 6; i++) {
      divisor *= 10;
    }
    final rounded = (micros + divisor ~/ 2) ~/ divisor;
    if (fractionDigits == 0) return rounded.toString();
    var fractionalScale = 1;
    for (var i = 0; i < fractionDigits; i++) {
      fractionalScale *= 10;
    }
    final whole = rounded ~/ fractionalScale;
    final fraction = (rounded % fractionalScale).toString().padLeft(
      fractionDigits,
      '0',
    );
    return '$whole.$fraction';
  }

  static String rate(double amount) {
    final fixed = amount.toStringAsFixed(6);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
