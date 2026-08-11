enum UserbotGiftError {
  userbotNotConnected,
  giftIdNotFound,
  balanceTooLow,
  peerIdInvalid,
  usernameInvalid,
  stargiftUsageLimited,
  stargiftInvalid,
  floodWait,
  timeout,
  unknown,
}

class UserbotGiftResult {
  const UserbotGiftResult._({
    required this.success,
    this.realGiftId,
    this.error,
    this.detail,
    this.waitSeconds,
  });

  factory UserbotGiftResult.success({int? realGiftId}) {
    return UserbotGiftResult._(success: true, realGiftId: realGiftId);
  }

  factory UserbotGiftResult.failure({
    required UserbotGiftError error,
    String? detail,
    int? waitSeconds,
  }) {
    return UserbotGiftResult._(
      success: false,
      error: error,
      detail: detail,
      waitSeconds: waitSeconds,
    );
  }

  final bool success;
  final int? realGiftId;
  final UserbotGiftError? error;
  final String? detail;
  final int? waitSeconds;
}
