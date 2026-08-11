import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price_client.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price_exception.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price_gateway.dart';
import 'package:test/test.dart';

void main() {
  test('price client parses current one-Star USD price exactly', () async {
    var calls = 0;
    final client = FragmentStarsPriceClient(
      baseUri: Uri.parse('https://fragment-api.ydns.eu:8443'),
      httpClient: MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'success': true,
            'stars': {
              'price_per_star_ton': '0.011112000',
              'price_per_star_usdt_ton': '0.015000',
            },
            'cached_at': DateTime.now().toUtc().toIso8601String(),
            'cache_expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
          }),
          200,
        );
      }),
    );

    final prices = await Future.wait([
      client.getUsdPerStar(),
      client.getUsdPerStar(),
    ]);
    final cached = await client.getUsdPerStar();

    expect(prices, everyElement(UsdAmount.parse('0.015')));
    expect(cached, UsdAmount.parse('0.015'));
    expect(calls, 1);
  });

  test('price client rejects malformed successful response', () async {
    final client = FragmentStarsPriceClient(
      baseUri: Uri.parse('https://fragment-api.ydns.eu:8443'),
      httpClient: MockClient(
        (request) async =>
            http.Response(jsonEncode({'success': true, 'stars': {}}), 200),
      ),
    );

    await expectLater(
      client.getUsdPerStar(),
      throwsA(isA<FragmentStarsPriceException>()),
    );
  });

  test('Stars markup is added to the complete product amount', () async {
    final pricing = FragmentPricingService(
      starsPriceGateway: FakeStarsPriceGateway('0.015'),
      starsMarkupPercent: '10',
    );

    final quote = await pricing.quoteStars(100);

    expect(quote.unitPrice, UsdAmount.parse('0.015'));
    expect(quote.basePrice, UsdAmount.parse('1.50'));
    expect(quote.markupAmount, UsdAmount.parse('0.15'));
    expect(quote.price, UsdAmount.parse('1.65'));
  });

  test('fractional markup percent stays exact', () async {
    final pricing = FragmentPricingService(
      starsPriceGateway: FakeStarsPriceGateway('0.015'),
      starsMarkupPercent: '8.8',
    );

    final quote = await pricing.quoteStars(1000);

    expect(quote.basePrice, UsdAmount.parse('15'));
    expect(quote.markupAmount, UsdAmount.parse('1.32'));
    expect(quote.price, UsdAmount.parse('16.32'));
  });
}

class FakeStarsPriceGateway implements FragmentStarsPriceGateway {
  FakeStarsPriceGateway(String usdPerStar)
    : _price = FragmentStarsPrice(
        usdPerStar: UsdAmount.parse(usdPerStar),
        tonPerStar: TonAmount.parse('0.01'),
      );

  final FragmentStarsPrice _price;

  @override
  Future<FragmentStarsPrice> getPrices() async => _price;

  @override
  Future<UsdAmount> getUsdPerStar() async => _price.usdPerStar;
}
