abstract final class MoneyFormatter {

  static String compact(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }
  static String fixed(double amount) => amount.toStringAsFixed(2);
}
