import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

abstract final class ReferralCodeGenerator {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const codeLength = 8;

  static String generateUnique(Database db, {Random? random}) {
    final rng = random ?? Random.secure();
    for (var attempt = 0; attempt < 100; attempt++) {
      final code = List.generate(
        codeLength,
        (_) => _chars[rng.nextInt(_chars.length)],
      ).join();
      final exists = db.select(
        'SELECT 1 FROM users WHERE referral_code = ? LIMIT 1',
        [code],
      );
      if (exists.isEmpty) return code;
    }
    throw StateError('Failed to generate unique referral code');
  }
}