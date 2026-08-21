class AdminPeriodCounts {
  const AdminPeriodCounts({
    required this.total,
    required this.lastDay,
    required this.lastWeek,
    required this.lastMonth,
  });

  final int total;
  final int lastDay;
  final int lastWeek;
  final int lastMonth;
}

class AdminPurchaseStatistics {
  const AdminPurchaseStatistics({
    required this.count,
    required this.quantity,
    required this.spentUsdMicros,
  });

  final int count;
  final double quantity;
  final int spentUsdMicros;
}

class AdminStatistics {
  const AdminStatistics({
    required this.generatedAt,
    required this.users,
    required this.referrals,
    required this.stars,
    required this.premium,
    required this.ton,
    required this.gifts,
    required this.failedOrders,
    required this.pendingOrders,
    required this.totalBalanceMicros,
  });

  final DateTime generatedAt;
  final AdminPeriodCounts users;
  final AdminPeriodCounts referrals;
  final AdminPurchaseStatistics stars;
  final AdminPurchaseStatistics premium;
  final AdminPurchaseStatistics ton;
  final AdminPurchaseStatistics gifts;
  final int failedOrders;
  final int pendingOrders;
  final int totalBalanceMicros;
}
