import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_models.dart';

abstract interface class FragmentGateway {
  Future<FragmentApiHealth> getHealth();

  Future<FragmentRecipient> searchUser(String username);

  Future<FragmentPurchaseReceipt> buyStars({
    required String recipient,
    required int amount,
  });

  Future<FragmentPurchaseReceipt> buyPremium({
    required String recipient,
    required int months,
  });

  Future<FragmentPurchaseReceipt> addTon({
    required String recipient,
    required TonAmount amount,
  });
}
