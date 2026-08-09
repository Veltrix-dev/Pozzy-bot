import 'package:pozzy_bot/database/models/user_balance.dart';
import 'package:pozzy_bot/database/repositories/user_balance_repository.dart';
class BalanceService {
  BalanceService(this._repo);

  final UserBalanceRepository _repo;
  
  UserBalance getBalance(int telegramId) {
    return _repo.findOrEmpty(telegramId);
  }
}
