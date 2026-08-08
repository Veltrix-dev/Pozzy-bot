class ReferralEntry {
ReferralEntry({
    required this.telegramId,
    required this.username,
    required this.joinedAt,
});

  final int telegramId;
  final String? username;
  final DateTime joinedAt;

}

class ReferralStats {
  ReferralStats({
    required this.invitedCount,
    required this.referrals,
  });

  
  final int invitedCount;
  final List<ReferralEntry> referrals;
}

enum ReferralRegisterOutcome {
  success,
  referrerNotFound,
  selfReferral,
  alreadyReferred,
}

class ReferralRegisterResult {
   ReferralRegisterResult({
    required this.outcome,
    this.referrerTelegramId,
  });

  final ReferralRegisterOutcome outcome;
  final int? referrerTelegramId;

  bool get isSuccess => outcome == ReferralRegisterOutcome.success;   
}



