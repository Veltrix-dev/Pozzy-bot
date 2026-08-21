import 'package:pozzy_bot/database/models/usd_amount.dart';

class StoredTonPrice {
  const StoredTonPrice({required this.usdPerTon, required this.fetchedAt});

  final UsdAmount usdPerTon;
  final DateTime fetchedAt;
}

abstract interface class TonPriceStore {
  StoredTonPrice? findLast();

  void save({required UsdAmount usdPerTon, required DateTime fetchedAt});
}
