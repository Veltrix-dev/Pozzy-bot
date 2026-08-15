abstract final class PremiumPurchaseCallbacks {
  static const prefix = 'purchase:premium:';
  static const threeMonths = '${prefix}3';
  static const sixMonths = '${prefix}6';
  static const twelveMonths = '${prefix}12';

  static int? durationMonths(String callbackData) => switch (callbackData) {
    threeMonths => 3,
    sixMonths => 6,
    twelveMonths => 12,
    _ => null,
  };
}
