import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/config/config_validator.dart';
import 'package:pozzy_bot/config/env_file_service.dart';
import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/repositories/exchange_rate_repository.dart';
import 'package:pozzy_bot/database/repositories/referral_repository.dart';
import 'package:pozzy_bot/database/repositories/fragment_order_repository.dart';
import 'package:pozzy_bot/database/repositories/fragment_star_price_repository.dart';
import 'package:pozzy_bot/database/repositories/user_balance_repository.dart';
import 'package:pozzy_bot/database/repositories/user_statistics_repository.dart';
import 'package:pozzy_bot/database/repositories/user_repositories.dart';
import 'package:pozzy_bot/handler/gift_menu_handler.dart';
import 'package:pozzy_bot/handler/main_menu_handler.dart';
import 'package:pozzy_bot/handler/purchase/fragment_purchase_coordinator.dart';
import 'package:pozzy_bot/handler/purchase/premium/premium_purchase_handler.dart';
import 'package:pozzy_bot/handler/purchase/recipient/recipient_selection_handler.dart';
import 'package:pozzy_bot/handler/purchase/stars/stars_purchase_handler.dart';
import 'package:pozzy_bot/handler/purchase/ton/ton_purchase_handler.dart';
import 'package:pozzy_bot/handler/register_handler.dart';
import 'package:pozzy_bot/handler/referral_inline_query_handler.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/handler/start_handler.dart';
import 'package:pozzy_bot/router/callback_router.dart';
import 'package:pozzy_bot/services/balance_service.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_notifier.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_client.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_purchase_flow_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_purchase_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_recipient_resolver.dart';
import 'package:pozzy_bot/services/referral/referral_service.dart';
import 'package:pozzy_bot/services/referral/referral_notification_service.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_service.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:pozzy_bot/services/user_statistics_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';

abstract class Bootstrap {
  static Future<void> run() async {
    final bot = await ConfigValidator.validateBotToken();
    await AppDatabase.init();

    await bot.api.setMyCommands([
      BotCommand(command: 'start', description: 'Главное меню'),
    ]);

    final envFileService = EnvFileService();
    final menuPhotoService = MenuPhotoService(envFile: envFileService);
    final reply = ReplyHandler(bot, menuPhotos: menuPhotoService);
    final userRepo = UserRepositories();
    final referralRepo = ReferralRepository();
    final statisticsRepo = UserStatisticsRepository();
    final balanceRepo = UserBalanceRepository();
    final exchangeRate = ExchangeRateService.fromConfig(
      store: ExchangeRateRepository(),
      notifier: ExchangeRateAdminNotifier(
        reply: reply,
        adminTelegramIds: Config.initialAdminTelegramIds,
      ),
    );
    await exchangeRate.start();

    final userService = UserService(userRepo);
    final statisticsService = UserStatisticsService(statisticsRepo);
    final balanceService = BalanceService(balanceRepo);
    final referralNotifications = ReferralNotificationService(
      reply: reply,
      users: userRepo,
      balance: balanceService,
    );
    final referralService = ReferralService(
      repo: referralRepo,
      users: userRepo,
      botUsername: Config.botUsername.isEmpty
          ? (bot.me.username ?? '')
          : Config.botUsername,
      notifications: referralNotifications,
    );
    final fragmentOrders = FragmentOrderRepository();
    final fragmentGateway = FragmentApiClient(
      baseUri: Uri.parse(Config.fragmentApiBaseUrl),
      walletSeedWords: Config.fragmentWalletSeedWords,
      timeout: Duration(seconds: Config.fragmentApiTimeoutSeconds),
    );
    final fragmentPricing = FragmentPricingService(
      starsPriceStore: FragmentStarPriceRepository(),
    );
    final fragmentPurchases = FragmentPurchaseService(
      orders: fragmentOrders,
      users: userRepo,
      gateway: fragmentGateway,
      pricing: fragmentPricing,
      referrals: referralService,
    );
    fragmentPurchases.restorePendingOrders(
      minimumAge: Duration(seconds: Config.fragmentPendingReviewAgeSeconds),
    );
    final start = StartHandler(userService, reply, referralService);
    final referralInlineQuery = ReferralInlineQueryHandler(referralService);
    final giftMenu = GiftMenuHandler(reply);
    final fragmentFlows = FragmentPurchaseFlowService();
    final fragmentPurchaseCoordinator = FragmentPurchaseCoordinator(
      reply: reply,
      flows: fragmentFlows,
    );
    final recipientSelection = RecipientSelectionHandler(
      reply: reply,
      flows: fragmentFlows,
      recipients: FragmentRecipientResolver(fragmentGateway),
      coordinator: fragmentPurchaseCoordinator,
    );
    final starsPurchase = StarsPurchaseHandler(
      reply: reply,
      users: userService,
      pricing: fragmentPricing,
      exchangeRate: exchangeRate,
      flows: fragmentFlows,
      recipientSelection: recipientSelection,
    );
    final premiumPurchase = PremiumPurchaseHandler(
      reply: reply,
      users: userService,
      pricing: fragmentPricing,
      flows: fragmentFlows,
      recipientSelection: recipientSelection,
      coordinator: fragmentPurchaseCoordinator,
    );
    final tonPurchase = TonPurchaseHandler(
      reply: reply,
      users: userService,
      pricing: fragmentPricing,
      flows: fragmentFlows,
      recipientSelection: recipientSelection,
      coordinator: fragmentPurchaseCoordinator,
    );
    final mainMenu = MainMenuHandler(
      reply: reply,
      users: userService,
      statistics: statisticsService,
      referrals: referralService,
      balance: balanceService,
    );
    final callbacks = CallbackRouter(
      mainMenu: mainMenu,
      giftMenu: giftMenu,
      starsPurchase: starsPurchase,
      premiumPurchase: premiumPurchase,
      tonPurchase: tonPurchase,
      recipientSelection: recipientSelection,
      purchaseCoordinator: fragmentPurchaseCoordinator,
    );

    RegisterHandler.register(
      bot,
      start: start,
      callbackRouter: callbacks,
      referralInlineQuery: referralInlineQuery,
      starsPurchase: starsPurchase,
      tonPurchase: tonPurchase,
      recipientSelection: recipientSelection,
      purchaseCoordinator: fragmentPurchaseCoordinator,
    );
    await bot.api.setChatMenuButton(MenuButton.commands());
    BotLog.info('started @${bot.me.username} verbose=${BotLog.verbose}');
    await bot.start(
      LongPollingFetcher(bot.api, config: const LongPollingConfig.lowLatency()),
    );
  }
}
