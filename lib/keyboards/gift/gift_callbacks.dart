import 'package:pozzy_bot/services/gift/gift_catalog.dart';

abstract final class GiftCallbacks {
  static const prefix = 'gift:';
  static const gift1 = '${prefix}1';
  static const gift2 = '${prefix}2';
  static const gift3 = '${prefix}3';
  static const gift4 = '${prefix}4';
  static const gift5 = '${prefix}5';
  static const gift6 = '${prefix}6';
  static const gift7 = '${prefix}7';
  static const gift8 = '${prefix}8';

  static GiftKind? parse(String callbackData) {
    return switch (callbackData) {
      gift1 => GiftKind.gift1,
      gift2 => GiftKind.gift2,
      gift3 => GiftKind.gift3,
      gift4 => GiftKind.gift4,
      gift5 => GiftKind.gift5,
      gift6 => GiftKind.gift6,
      gift7 => GiftKind.gift7,
      gift8 => GiftKind.gift8,
      _ => null,
    };
  }
}
