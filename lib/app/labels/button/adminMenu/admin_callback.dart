abstract class AdminCallback {
  static const openPanel = 'admin:panel';
  static const statistics = 'admin:statistics';
  static const topUpUserBalance = 'admin:topup_user_balance';
  static const userInfo = 'admin:user_info';
  static const broadcast = 'admin:broadcast';
  static const administrators = 'admin:administrators';
  static const cancel = 'admin:cancel';
  static const close = 'admin:close';
  static const topUpConfirmPrefix = 'admin:topup_confirm:';
  static const broadcastConfirmPrefix = 'admin:broadcast_confirm:';

  static bool isAdminCallback(String data) => data.startsWith('admin:');

  static String? parseTopUpConfirmation(String data) =>
      _parseToken(data, topUpConfirmPrefix);

  static String? parseBroadcastConfirmation(String data) =>
      _parseToken(data, broadcastConfirmPrefix);

  static String? _parseToken(String data, String prefix) {
    if (!data.startsWith(prefix)) return null;
    final token = data.substring(prefix.length).trim();
    return token.isEmpty ? null : token;
  }
}
