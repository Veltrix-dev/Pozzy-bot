class UserStatistics {
  UserStatistics({
    required this.telegramId,
    required this.purchasesCount,
    required this.purchasesTotal,
    required this.referralCommissionTotal,
    required this.updatedAt,
  });

  final int telegramId;
  final int purchasesCount;
  final double purchasesTotal;
  final double referralCommissionTotal;
  final DateTime updatedAt;

  factory UserStatistics.empty(int telegramId) {
    return UserStatistics(
      telegramId: telegramId,
      purchasesCount: 0,
      purchasesTotal: 0,
      referralCommissionTotal: 0,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  factory UserStatistics.fromMap(Map<String, dynamic> map) {
    return UserStatistics(
      telegramId: map['telegram_id'] as int,
      purchasesCount: map['purchases_count'] as int,
      purchasesTotal: (map['purchases_total'] as num).toDouble(),
      referralCommissionTotal:
          (map['referral_commission_total'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
