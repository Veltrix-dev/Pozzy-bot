abstract class AdminCallback {
  static const openPanel = 'admin:panel';
  static const statistics = 'admin:statistics';
  static const promoCode = 'admin:promo_code';
  static const generatePromoCode = 'admin:promo_generate';
  static const changeCoinCourse = 'admin:change_coin_course';
  static const changePrices = 'admin:change_prices';
  static const topUpUserBalance = 'admin:topup_user_balance';
  static const management = 'admin:management';
  static const contactDeveloper = 'admin:contact_developer';
  static const userInfo = 'admin:user_info';
  static const broadcast = 'admin:broadcast';

  static bool isAdminCallback(String data) => data.startsWith('admin:');

  static const _publicCallbacks = <String>{};

  static bool requiresAuth(String data) => !_publicCallbacks.contains(data); 
}