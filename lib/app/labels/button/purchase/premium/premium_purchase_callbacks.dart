abstract final class PremiumPurchaseCallbacks {
  static const prefix = 'purchase:premium:';
  static const threeMonths = '${prefix}3';
  static const sixMonths = '${prefix}6';
  static const twelveMonths = '${prefix}12';

  static const durationMonthsValues = [3, 6, 12];

  static PremiumDurationSelection? durationSelection(String callbackData) {
    if (!callbackData.startsWith(prefix)) return null;
    final value = callbackData.substring(prefix.length);
    final parts = value.split(':');
    if (parts.length != 2 || parts.first.isEmpty) return null;
    final months = int.tryParse(parts.last);
    if (months == null || !durationMonthsValues.contains(months)) return null;
    return PremiumDurationSelection(generation: parts.first, months: months);
  }

  static String durationCallback({
    required String generation,
    required int months,
  }) => '$prefix$generation:$months';
}

class PremiumDurationSelection {
  const PremiumDurationSelection({
    required this.generation,
    required this.months,
  });

  final String generation;
  final int months;
}
