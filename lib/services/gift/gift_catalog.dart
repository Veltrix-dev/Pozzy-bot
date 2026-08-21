import 'package:pozzy_bot/app/labels/id/gift_ids.dart';
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/rub_amount.dart';

enum GiftKind {
  gift1,
  gift2,
  gift3,
  gift4,
  gift5,
  gift6,
  gift7,
  gift8,
  gift9,
}

class GiftProduct {
  const GiftProduct({
    required this.kind,
    required this.telegramGiftId,
    required this.priceRub,
    required this.priceUsd,
  });

  final GiftKind kind;
  final String telegramGiftId;
  final RubAmount priceRub;
  final double priceUsd;

  int get number => kind.index + 1;
}

abstract final class GiftCatalog {
  static List<GiftProduct> get products => [
    for (final kind in GiftKind.values) productFor(kind),
  ];

  static GiftProduct productFor(GiftKind kind) {
    final giftIndex = kind.index + 1;
    return GiftProduct(
      kind: kind,
      telegramGiftId: _giftIdFor(kind),
      priceRub: Config.giftPriceRub(giftIndex),
      priceUsd: Config.giftPriceUsd(giftIndex),
    );
  }

  static String _giftIdFor(GiftKind kind) {
    return switch (kind) {
      GiftKind.gift1 => GiftIds.gift1,
      GiftKind.gift2 => GiftIds.gift2,
      GiftKind.gift3 => GiftIds.gift3,
      GiftKind.gift4 => GiftIds.gift4,
      GiftKind.gift5 => GiftIds.gift5,
      GiftKind.gift6 => GiftIds.gift6,
      GiftKind.gift7 => GiftIds.gift7,
      GiftKind.gift8 => GiftIds.gift8,
      GiftKind.gift9 => GiftIds.gift9,
    };
  }
}
