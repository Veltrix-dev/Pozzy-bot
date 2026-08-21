import 'package:pozzy_bot/database/models/user.dart';

class AdminUserSnapshot {
  const AdminUserSnapshot({
    required this.user,
    required this.balanceMicros,
    required this.purchasesCount,
    required this.purchasesTotalMicros,
    required this.invitedCount,
  });

  final User user;
  final int balanceMicros;
  final int purchasesCount;
  final int purchasesTotalMicros;
  final int invitedCount;
}

enum AdminCreditOutcome { applied, alreadyApplied, targetMissing }

class AdminCreditResult {
  const AdminCreditResult({required this.outcome, required this.balanceMicros});

  final AdminCreditOutcome outcome;
  final int balanceMicros;
}
