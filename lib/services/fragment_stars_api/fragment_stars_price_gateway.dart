import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price.dart';

abstract interface class FragmentStarsPriceGateway {
  Future<FragmentStarsPrice> getPrices();

  Future<UsdAmount> getUsdPerStar();
}
