import 'package:pozzy_bot/database/models/usd_amount.dart';

class StoredFragmentStarPrice {
  const StoredFragmentStarPrice({
    required this.usdPerStar,
    required this.fetchedAt,
  });

  final UsdAmount usdPerStar;
  final DateTime fetchedAt;
}

abstract interface class FragmentStarPriceStore {
  StoredFragmentStarPrice? findLast();

  void save({required UsdAmount usdPerStar, required DateTime fetchedAt});
}
