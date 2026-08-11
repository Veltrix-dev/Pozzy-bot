import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_client.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_exception.dart';
import 'package:test/test.dart';

void main() {
  final seed = List<String>.generate(24, (index) => 'word$index');

  test('TON request keeps exact nine-decimal JSON number', () async {
    String? requestBody;
    final client = FragmentApiClient(
      baseUri: Uri.parse('https://fragment-api.arijitiyan.cc'),
      walletSeedWords: seed,
      httpClient: MockClient((request) async {
        requestBody = request.body;
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {
              'user': 'Target',
              'username': 'target_user',
              'ton_paid': '0.123456789',
              'amount_requested': '0.123456789',
            },
          }),
          200,
        );
      }),
    );

    final result = await client.addTon(
      recipient: 'target_user',
      amount: TonAmount.parse('0.123456789'),
    );

    expect(requestBody, contains('"amount":0.123456789'));
    expect(result.deliveredUnits, 123456789);
  });

  test('HTTP 400 with ok false becomes definitive client error', () async {
    final client = FragmentApiClient(
      baseUri: Uri.parse('https://fragment-api.arijitiyan.cc'),
      walletSeedWords: seed,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'ok': false, 'message': 'Minimum amount is 50 stars.'}),
          400,
        );
      }),
    );

    await expectLater(
      client.buyStars(recipient: 'target_user', amount: 50),
      throwsA(
        isA<FragmentApiException>()
            .having(
              (error) => error.kind,
              'kind',
              FragmentApiErrorKind.httpClient,
            )
            .having(
              (error) => error.executionUncertain,
              'executionUncertain',
              false,
            ),
      ),
    );
  });

  test('malformed successful purchase response is uncertain', () async {
    final client = FragmentApiClient(
      baseUri: Uri.parse('https://fragment-api.arijitiyan.cc'),
      walletSeedWords: seed,
      httpClient: MockClient((request) async => http.Response('not-json', 200)),
    );

    await expectLater(
      client.buyPremium(recipient: 'target_user', months: 3),
      throwsA(
        isA<FragmentApiException>()
            .having(
              (error) => error.kind,
              'kind',
              FragmentApiErrorKind.malformedResponse,
            )
            .having(
              (error) => error.executionUncertain,
              'executionUncertain',
              true,
            ),
      ),
    );
  });

  test('wallet seed must contain exactly 24 words', () async {
    final client = FragmentApiClient(
      baseUri: Uri.parse('https://fragment-api.arijitiyan.cc'),
      walletSeedWords: const ['one', 'two'],
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );

    await expectLater(
      client.buyStars(recipient: 'target_user', amount: 50),
      throwsA(
        isA<FragmentApiException>().having(
          (error) => error.kind,
          'kind',
          FragmentApiErrorKind.configuration,
        ),
      ),
    );
  });
}
