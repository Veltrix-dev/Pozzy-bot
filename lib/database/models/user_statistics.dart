abstract final class UserPurchaseTypes {
  static const stars = 'stars';
  static const premium = 'premium';
  static const ton = 'ton';

  static const values = {stars, premium, ton};
}

class UserPurchaseEntry {
  UserPurchaseEntry({
    required this.purchasedAt,
    required this.quantity,
    required this.spentUsd,
  });

  final DateTime purchasedAt;
  final double quantity;
  final double spentUsd;
}

class UserStatistics {
  UserStatistics({
    required this.telegramId,
    required this.purchasesCount,
    required this.purchasesTotal,
    required this.referralCommissionTotal,
    required this.updatedAt,
    this.starsPurchases = const [],
    this.premiumPurchases = const [],
    this.tonPurchases = const [],
    this.giftPurchases = const [],
  });

  final int telegramId;
  final int purchasesCount;
  final double purchasesTotal;
  final double referralCommissionTotal;
  final DateTime updatedAt;
  final List<UserPurchaseEntry> starsPurchases;
  final List<UserPurchaseEntry> premiumPurchases;
  final List<UserPurchaseEntry> tonPurchases;
  final List<UserPurchaseEntry> giftPurchases;

  factory UserStatistics.empty(int telegramId) {
    return UserStatistics(
      telegramId: telegramId,
      purchasesCount: 0,
      purchasesTotal: 0,
      referralCommissionTotal: 0,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  factory UserStatistics.fromMap(
    Map<String, dynamic> map, {
    List<UserPurchaseEntry> starsPurchases = const [],
    List<UserPurchaseEntry> premiumPurchases = const [],
    List<UserPurchaseEntry> tonPurchases = const [],
    List<UserPurchaseEntry> giftPurchases = const [],
  }) {
    return UserStatistics(
      telegramId: map['telegram_id'] as int,
      purchasesCount: map['purchases_count'] as int,
      purchasesTotal: (map['purchases_total'] as num).toDouble(),
      referralCommissionTotal: (map['referral_commission_total'] as num)
          .toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      starsPurchases: starsPurchases,
      premiumPurchases: premiumPurchases,
      tonPurchases: tonPurchases,
      giftPurchases: giftPurchases,
    );
  }
}
