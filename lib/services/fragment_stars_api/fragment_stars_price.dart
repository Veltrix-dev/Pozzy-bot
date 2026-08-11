import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';

class FragmentStarsPrice {
  const FragmentStarsPrice({
    required this.usdPerStar,
    required this.tonPerStar,
    this.cachedAt,
    this.cacheExpiresAt,
  });

  factory FragmentStarsPrice.fromJson(Map<String, dynamic> payload) {
    final stars = payload['stars'];
    if (stars is! Map<String, dynamic>) {
      throw const FormatException('Missing stars price object');
    }

    final usdPerStar = _parseUsd(stars['price_per_star_usdt_ton']);
    final tonPerStar = _parseTon(stars['price_per_star_ton']);
    if (usdPerStar.isZero || tonPerStar.isZero) {
      throw const FormatException('Stars price must be positive');
    }

    return FragmentStarsPrice(
      usdPerStar: usdPerStar,
      tonPerStar: tonPerStar,
      cachedAt: _parseDate(payload['cached_at']),
      cacheExpiresAt: _parseDate(payload['cache_expires_at']),
    );
  }

  final UsdAmount usdPerStar;
  final TonAmount tonPerStar;
  final DateTime? cachedAt;
  final DateTime? cacheExpiresAt;
}

UsdAmount _parseUsd(Object? value) {
  try {
    return UsdAmount.parse(value?.toString() ?? '');
  } on FormatException {
    throw const FormatException('Invalid price_per_star_usdt_ton');
  }
}

TonAmount _parseTon(Object? value) {
  try {
    return TonAmount.parse(value?.toString() ?? '');
  } on FormatException {
    throw const FormatException('Invalid price_per_star_ton');
  }
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
