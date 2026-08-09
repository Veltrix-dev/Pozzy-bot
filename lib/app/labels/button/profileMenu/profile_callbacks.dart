abstract final class ProfileCallbacks {
  static const prefix = 'profile:';
  static const referrals = 'profile:referrals';
  static const referralsList = 'profile:referrals_list';
  static const statistics = 'profile:statistics';

  static bool isProfileCallback(String data) => data.startsWith(prefix);
}
