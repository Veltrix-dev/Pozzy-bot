import 'package:pozzy_bot/database/models/user_statistics.dart';
import 'package:pozzy_bot/database/repositories/user_statistics_repository.dart';

class UserStatisticsService {
  UserStatisticsService(this._repo);

  final UserStatisticsRepository _repo;

  UserStatistics buildForUser(int telegramId) {
    return _repo.findOrEmpty(telegramId);
  }

  void recordPurchase({
    required int telegramId,
    required double amount,
    String? purchaseId,
    String? purchaseType,
    double? quantity,
    DateTime? purchasedAt,
  }) {
    _repo.recordPurchase(
      telegramId: telegramId,
      amount: amount,
      purchaseId: purchaseId,
      purchaseType: purchaseType,
      quantity: quantity,
      purchasedAt: purchasedAt,
    );
  }
}
