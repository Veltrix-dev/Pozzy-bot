import 'dart:io';

import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/fragment_order_status.dart';
import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/database/models/user_roles.dart';
import 'package:pozzy_bot/database/repositories/fragment_order_repository.dart';
import 'package:pozzy_bot/database/repositories/user_repositories.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_exception.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_models.dart';
import 'package:pozzy_bot/services/fragment/fragment_gateway.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_purchase_service.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price_exception.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price_gateway.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDirectory;
  late String databasePath;
  late FakeFragmentGateway gateway;
  late FragmentPurchaseService service;

  setUp(() async {
    AppDatabase.close();
    tempDirectory = await Directory.systemTemp.createTemp('pozzy_fragment_');
    databasePath = '${tempDirectory.path}${Platform.pathSeparator}test.db';
    await AppDatabase.init(pathOverride: databasePath);
    final users = UserRepositories();
    users.insert(
      telegramId: 1001,
      username: 'buyer_user',
      role: UserRoles.user,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    AppDatabase.instance.execute(
      '''
      INSERT INTO user_balances (
        telegram_id, balance, balance_micros, updated_at
      ) VALUES (?, ?, ?, ?);
      ''',
      [1001, 10.0, 10000000, now],
    );
    gateway = FakeFragmentGateway();
    service = FragmentPurchaseService(
      orders: FragmentOrderRepository(),
      users: users,
      gateway: gateway,
      pricing: FragmentPricingService(
        starPriceUsd: '0.02',
        tonPriceUsd: '2.50',
        premiumPricesUsd: const {3: '3.00', 6: '5.50', 12: '10.00'},
      ),
    );
  });

  tearDown(() async {
    AppDatabase.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'duplicate idempotency key executes and records purchase once',
    () async {
      final first = await service.purchaseStars(
        idempotencyKey: 'payment-001',
        buyerTelegramId: 1001,
        recipientUsername: '@target_user',
        amount: 100,
      );
      final second = await service.purchaseStars(
        idempotencyKey: 'payment-001',
        buyerTelegramId: 1001,
        recipientUsername: 'target_user',
        amount: 100,
      );

      expect(first.outcome, FragmentPurchaseOutcome.completed);
      expect(second.outcome, FragmentPurchaseOutcome.alreadyCompleted);
      expect(second.order?.orderId, first.order?.orderId);
      expect(gateway.starsCalls, 1);
      expect(_balanceMicros(), 8000000);
      expect(_scalarInt('SELECT purchases_count FROM user_statistics'), 1);
      expect(_scalarInt('SELECT COUNT(*) FROM user_purchase_history'), 1);
    },
  );

  test(
    'duplicate completed order does not request a new Stars price',
    () async {
      final priceGateway = CountingStarsPriceGateway();
      final dynamicPricingService = FragmentPurchaseService(
        orders: FragmentOrderRepository(),
        users: UserRepositories(),
        gateway: gateway,
        pricing: FragmentPricingService(
          starsPriceGateway: priceGateway,
          starsMarkupPercent: '0',
        ),
      );

      final first = await dynamicPricingService.purchaseStars(
        idempotencyKey: 'dynamic-price-payment',
        buyerTelegramId: 1001,
        recipientUsername: 'target_user',
        amount: 100,
      );
      priceGateway.fail = true;
      final second = await dynamicPricingService.purchaseStars(
        idempotencyKey: 'dynamic-price-payment',
        buyerTelegramId: 1001,
        recipientUsername: 'target_user',
        amount: 100,
      );

      expect(first.outcome, FragmentPurchaseOutcome.completed);
      expect(second.outcome, FragmentPurchaseOutcome.alreadyCompleted);
      expect(priceGateway.calls, 1);
      expect(gateway.starsCalls, 1);
    },
  );

  test('timeout keeps processing order reserved and prevents retry', () async {
    gateway.purchaseError = const FragmentApiException(
      kind: FragmentApiErrorKind.timeout,
      message: 'timeout',
      executionUncertain: true,
    );

    final first = await service.purchaseStars(
      idempotencyKey: 'payment-timeout',
      buyerTelegramId: 1001,
      recipientUsername: 'target_user',
      amount: 100,
    );
    final second = await service.purchaseStars(
      idempotencyKey: 'payment-timeout',
      buyerTelegramId: 1001,
      recipientUsername: 'target_user',
      amount: 100,
    );

    expect(first.outcome, FragmentPurchaseOutcome.pendingConfirmation);
    expect(second.outcome, FragmentPurchaseOutcome.pendingConfirmation);
    expect(first.order?.status, FragmentOrderStatus.processing);
    expect(gateway.starsCalls, 1);
    expect(_balanceMicros(), 8000000);

    AppDatabase.close();
    await AppDatabase.init(pathOverride: databasePath);
    final restoredService = FragmentPurchaseService(
      orders: FragmentOrderRepository(),
      users: UserRepositories(),
      gateway: gateway,
      pricing: FragmentPricingService(starPriceUsd: '0.02'),
    );
    final restored = restoredService.restorePendingOrders();

    expect(restored, hasLength(1));
    expect(restored.single.orderId, first.order?.orderId);
    expect(restored.single.status, FragmentOrderStatus.processing);
  });

  test('definitive API rejection fails order and refunds balance', () async {
    gateway.purchaseError = const FragmentApiException(
      kind: FragmentApiErrorKind.rejected,
      message: 'recipient cannot receive stars',
    );

    final result = await service.purchaseStars(
      idempotencyKey: 'payment-rejected',
      buyerTelegramId: 1001,
      recipientUsername: 'target_user',
      amount: 100,
    );
    final repeated = await service.purchaseStars(
      idempotencyKey: 'payment-rejected',
      buyerTelegramId: 1001,
      recipientUsername: 'target_user',
      amount: 100,
    );

    expect(result.outcome, FragmentPurchaseOutcome.apiRejected);
    expect(result.order?.status, FragmentOrderStatus.failed);
    expect(repeated.outcome, FragmentPurchaseOutcome.failed);
    expect(gateway.starsCalls, 1);
    expect(_balanceMicros(), 10000000);
  });

  test('mismatched success response stays pending without refund', () async {
    gateway.receiptOverride = const FragmentPurchaseReceipt(
      purchaseType: FragmentPurchaseType.stars,
      user: 'Target',
      username: 'target_user',
      tonPaid: TonAmount.fromNano(100000000),
      deliveredUnits: 99,
    );

    final result = await service.purchaseStars(
      idempotencyKey: 'payment-mismatch',
      buyerTelegramId: 1001,
      recipientUsername: 'target_user',
      amount: 100,
    );

    expect(result.outcome, FragmentPurchaseOutcome.pendingConfirmation);
    expect(result.order?.status, FragmentOrderStatus.processing);
    expect(result.order?.errorCode, 'response_mismatch');
    expect(_balanceMicros(), 8000000);
  });

  test('same idempotency key with another product is rejected', () async {
    final first = await service.purchaseStars(
      idempotencyKey: 'payment-conflict',
      buyerTelegramId: 1001,
      recipientUsername: 'target_user',
      amount: 100,
    );
    final conflict = await service.purchasePremium(
      idempotencyKey: 'payment-conflict',
      buyerTelegramId: 1001,
      recipientUsername: 'target_user',
      months: 3,
    );

    expect(first.outcome, FragmentPurchaseOutcome.completed);
    expect(conflict.outcome, FragmentPurchaseOutcome.idempotencyConflict);
    expect(gateway.starsCalls, 1);
    expect(gateway.premiumCalls, 0);
  });

  test('concurrent duplicate calls execute external purchase once', () async {
    final results = await Future.wait([
      service.purchaseStars(
        idempotencyKey: 'payment-concurrent',
        buyerTelegramId: 1001,
        recipientUsername: 'target_user',
        amount: 100,
      ),
      service.purchaseStars(
        idempotencyKey: 'payment-concurrent',
        buyerTelegramId: 1001,
        recipientUsername: 'target_user',
        amount: 100,
      ),
    ]);

    expect(gateway.starsCalls, 1);
    expect(_balanceMicros(), 8000000);
    expect(
      results.map((result) => result.outcome),
      contains(FragmentPurchaseOutcome.completed),
    );
    expect(
      results.every(
        (result) =>
            result.outcome == FragmentPurchaseOutcome.completed ||
            result.outcome == FragmentPurchaseOutcome.pendingConfirmation ||
            result.outcome == FragmentPurchaseOutcome.purchaseInProgress,
      ),
      isTrue,
    );
  });

  test('insufficient balance does not call purchase endpoint', () async {
    final result = await service.purchaseStars(
      idempotencyKey: 'payment-expensive',
      buyerTelegramId: 1001,
      recipientUsername: 'target_user',
      amount: 1000,
    );

    expect(result.outcome, FragmentPurchaseOutcome.insufficientBalance);
    expect(result.order?.status, FragmentOrderStatus.created);
    expect(gateway.starsCalls, 0);
    expect(_balanceMicros(), 10000000);
  });

  test(
    'input validation rejects numeric recipient and bad quantities',
    () async {
      final recipient = await service.purchaseStars(
        idempotencyKey: 'invalid-recipient',
        buyerTelegramId: 1001,
        recipientUsername: '123456789',
        amount: 100,
      );
      final stars = await service.purchaseStars(
        idempotencyKey: 'invalid-stars',
        buyerTelegramId: 1001,
        recipientUsername: 'target_user',
        amount: 49,
      );
      final premium = await service.purchasePremium(
        idempotencyKey: 'invalid-premium',
        buyerTelegramId: 1001,
        recipientUsername: 'target_user',
        months: 1,
      );
      final ton = await service.purchaseTon(
        idempotencyKey: 'invalid-ton',
        buyerTelegramId: 1001,
        recipientUsername: 'target_user',
        amount: '0.0000000001',
      );

      expect(recipient.outcome, FragmentPurchaseOutcome.invalidTelegramId);
      expect(stars.outcome, FragmentPurchaseOutcome.invalidStarsAmount);
      expect(premium.outcome, FragmentPurchaseOutcome.invalidPremiumDuration);
      expect(ton.outcome, FragmentPurchaseOutcome.invalidTonAmount);
      expect(gateway.totalPurchaseCalls, 0);
    },
  );
}

int _balanceMicros() {
  final rows = AppDatabase.instance.select(
    'SELECT balance_micros FROM user_balances WHERE telegram_id = 1001;',
  );
  return rows.first['balance_micros'] as int;
}

int _scalarInt(String sql) {
  final row = AppDatabase.instance.select(sql).first;
  return row.values.first as int;
}

class FakeFragmentGateway implements FragmentGateway {
  FragmentApiException? purchaseError;
  FragmentPurchaseReceipt? receiptOverride;
  int starsCalls = 0;
  int premiumCalls = 0;
  int tonCalls = 0;

  int get totalPurchaseCalls => starsCalls + premiumCalls + tonCalls;

  @override
  Future<FragmentApiHealth> getHealth() async {
    return const FragmentApiHealth(
      healthy: true,
      version: '2.0.0',
      cookieExists: true,
      cookieValid: true,
    );
  }

  @override
  Future<FragmentRecipient> searchUser(String username) async {
    return FragmentRecipient(name: 'Target', username: username);
  }

  @override
  Future<FragmentPurchaseReceipt> buyStars({
    required String recipient,
    required int amount,
  }) async {
    starsCalls++;
    _throwPurchaseError();
    return receiptOverride ??
        FragmentPurchaseReceipt(
          purchaseType: FragmentPurchaseType.stars,
          user: 'Target',
          username: recipient,
          tonPaid: const TonAmount.fromNano(100000000),
          deliveredUnits: amount,
        );
  }

  @override
  Future<FragmentPurchaseReceipt> buyPremium({
    required String recipient,
    required int months,
  }) async {
    premiumCalls++;
    _throwPurchaseError();
    return receiptOverride ??
        FragmentPurchaseReceipt(
          purchaseType: FragmentPurchaseType.premium,
          user: 'Target',
          username: recipient,
          tonPaid: const TonAmount.fromNano(100000000),
          deliveredUnits: months,
        );
  }

  @override
  Future<FragmentPurchaseReceipt> addTon({
    required String recipient,
    required TonAmount amount,
  }) async {
    tonCalls++;
    _throwPurchaseError();
    return receiptOverride ??
        FragmentPurchaseReceipt(
          purchaseType: FragmentPurchaseType.ton,
          user: 'Target',
          username: recipient,
          tonPaid: amount,
          deliveredUnits: amount.nano,
        );
  }

  void _throwPurchaseError() {
    final error = purchaseError;
    if (error != null) throw error;
  }
}

class CountingStarsPriceGateway implements FragmentStarsPriceGateway {
  int calls = 0;
  bool fail = false;

  @override
  Future<UsdAmount> getUsdPerStar() async {
    calls++;
    if (fail) {
      throw const FragmentStarsPriceException(
        'Price API unavailable',
        isNetworkError: true,
      );
    }
    return UsdAmount.parse('0.02');
  }

  @override
  Future<FragmentStarsPrice> getPrices() async {
    return FragmentStarsPrice(
      usdPerStar: await getUsdPerStar(),
      tonPerStar: TonAmount.parse('0.01'),
    );
  }
}
