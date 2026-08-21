abstract final class StarsPurchaseCallbacks {
  static const prefix = 'purchase:stars:';
  static const packageAmounts = [50, 100, 150, 250, 500, 1000, 2500];
  static const stars50 = '${prefix}50';
  static const stars100 = '${prefix}100';
  static const stars150 = '${prefix}150';
  static const stars250 = '${prefix}250';
  static const stars500 = '${prefix}500';
  static const stars1000 = '${prefix}1000';
  static const stars2500 = '${prefix}2500';
  static const customAmount = '${prefix}custom';

  static StarsPackageSelection? packageSelection(String callbackData) {
    if (!callbackData.startsWith(prefix)) return null;
    final value = callbackData.substring(prefix.length);
    final parts = value.split(':');
    if (parts.length != 2 || parts.first.isEmpty) return null;
    final amount = int.tryParse(parts.last);
    if (amount == null || !packageAmounts.contains(amount)) return null;
    return StarsPackageSelection(generation: parts.first, amount: amount);
  }

  static String packageCallback({
    required String generation,
    required int amount,
  }) => '$prefix$generation:$amount';
}

class StarsPackageSelection {
  const StarsPackageSelection({required this.generation, required this.amount});

  final String generation;
  final int amount;
}
