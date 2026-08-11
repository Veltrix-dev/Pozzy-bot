import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';
import 'package:test/test.dart';

void main() {
  test('USD parser stores exact micros', () {
    expect(UsdAmount.parse('12.345678').micros, 12345678);
    expect(UsdAmount.parse('12.340000').toDecimalString(), '12.34');
    expect(() => UsdAmount.parse('1.0000001'), throwsFormatException);
  });

  test('TON parser stores exact nanoTON', () {
    expect(TonAmount.parse('0.123456789').nano, 123456789);
    expect(TonAmount.parse('2.500000000').toDecimalString(), '2.5');
    expect(() => TonAmount.parse('0.0000000001'), throwsFormatException);
  });

  test('TON quote rounds up only the final micro-dollar', () {
    final pricing = FragmentPricingService(tonPriceUsd: '2.50');
    final quote = pricing.quoteTon(TonAmount.parse('0.000000001'));

    expect(quote.price.micros, 1);
  });

  test('referral fraction is calculated and rounded without double', () {
    final commission = UsdAmount.parse(
      '12.34',
    ).multiplyFraction('0.15', roundToCents: true);

    expect(commission.micros, 1850000);
    expect(commission.toDecimalString(), '1.85');
  });
}
