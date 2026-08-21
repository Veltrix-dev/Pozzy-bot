import 'package:pozzy_bot/database/models/usd_amount.dart';

abstract interface class GeckoTerminalTonPriceGateway {
  Future<UsdAmount> getTonUsdPrice();
}
