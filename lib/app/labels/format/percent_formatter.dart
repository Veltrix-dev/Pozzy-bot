abstract final class PercentFormatter {
  static String format(double fraction) {
    final value = fraction * 100;
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}
