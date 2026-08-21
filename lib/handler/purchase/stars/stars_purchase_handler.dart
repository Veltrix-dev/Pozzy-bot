import 'dart:math';

import 'package:pozzy_bot/app/labels/button/purchase/stars/stars_purchase_callbacks.dart';
import 'package:pozzy_bot/app/labels/message/purchase/common/fragment_purchase_result_text.dart';
import 'package:pozzy_bot/app/labels/message/purchase/stars/stars_purchase_text.dart';
import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/database/models/rub_amount.dart';
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/handler/purchase/recipient/recipient_selection_handler.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/keyboards/stars/stars_amount_keyboard.dart';
import 'package:pozzy_bot/keyboards/stars/stars_purchase_keyboard.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_exception.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_exception.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_purchase_flow_service.dart';
import 'package:pozzy_bot/services/fragment/price_menu_session_store.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_key.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/televerse.dart';

class StarsPurchaseHandler {
  StarsPurchaseHandler({
    required ReplyHandler reply,
    required UserService users,
    required FragmentPricingService pricing,
    required ExchangeRateService exchangeRate,
    required FragmentPurchaseFlowService flows,
    required RecipientSelectionHandler recipientSelection,
    Duration? menuPriceTtl,
    DateTime Function()? clock,
    Random? random,
  }) : _reply = reply,
       _users = users,
       _pricing = pricing,
       _exchangeRate = exchangeRate,
       _flows = flows,
       _recipientSelection = recipientSelection,
       _priceSessions = PriceMenuSessionStore(
         ttl:
             menuPriceTtl ??
             Duration(seconds: Config.exchangeRateMenuPriceTtlSeconds),
         clock: clock,
         random: random,
       );

  final ReplyHandler _reply;
  final UserService _users;
  final FragmentPricingService _pricing;
  final ExchangeRateService _exchangeRate;
  final FragmentPurchaseFlowService _flows;
  final RecipientSelectionHandler _recipientSelection;
  final PriceMenuSessionStore<Map<int, _StarsPackagePrice>> _priceSessions;

  Future<void> onOpen(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;
    _flows.cancel(from.id);
    final requestVersion = _priceSessions.beginLoad(from.id);
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    try {
      final packagePricesRub = await _loadPackagePricesRub();
      final generation = _priceSessions.completeLoad(
        buyerTelegramId: from.id,
        version: requestVersion,
        value: packagePricesRub,
      );
      if (generation == null) return;
      await _reply.sendMenuWithPhoto(
        ctx.id,
        photo: MenuPhotoKey.buyStars,
        text: StarsPurchaseText.menu,
        replyMarkup: StarsPurchaseKeyboard(
          packagePricesRub: packagePricesRub.map(
            (amount, price) => MapEntry(amount, price.displayedRub),
          ),
          generation: generation,
        ).markup,
      );
    } on FragmentApiException catch (error) {
      if (!_priceSessions.failLoad(from.id, requestVersion)) return;
      await _handlePricingFailure(ctx, error);
    } on ExchangeRateException catch (error) {
      if (!_priceSessions.failLoad(from.id, requestVersion)) return;
      await _handleExchangeRateFailure(ctx, error);
    }
  }

  Future<void> onSelectPackage(
    Context ctx,
    StarsPackageSelection selection,
  ) async {
    final from = ctx.from;
    if (from == null) return;
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    try {
      final packagePrice = _takePackagePriceRub(
        buyerTelegramId: from.id,
        selection: selection,
      );
      if (packagePrice == null) {
        await _reply.sendText(ctx.id, FragmentPurchaseResultText.priceExpired);
        return;
      }
      _flows.cancel(from.id);
      _flows.startAwaitingRecipient(
        buyerTelegramId: from.id,
        quote: packagePrice.quote,
        priceRub: packagePrice.exactRub,
      );
      await _showSelectedQuote(
        ctx,
        packagePrice.quote,
        packagePrice.displayedRub,
      );
    } on FragmentApiException catch (error) {
      await _handlePricingFailure(ctx, error);
    } on ExchangeRateException catch (error) {
      await _handleExchangeRateFailure(ctx, error);
    }
  }

  Future<void> onCustomAmount(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;
    _flows.cancel(from.id);
    _priceSessions.remove(from.id);
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    _flows.startAwaitingAmount(
      buyerTelegramId: from.id,
      purchaseType: FragmentPurchaseType.stars,
    );
    await _reply.sendText(
      ctx.id,
      StarsPurchaseText.enterAmount,
      replyMarkup: StarsAmountKeyboard().markup,
    );
  }

  Future<void> onExpiredPrice(Context ctx) {
    return _reply.sendText(ctx.id, FragmentPurchaseResultText.priceExpired);
  }

  Future<bool> onAnyMessage(Context ctx) async {
    final from = ctx.from;
    if (from == null) return false;
    final draft = _flows.find(from.id);
    if (draft == null ||
        draft.step != FragmentPurchaseFlowStep.awaitingAmount ||
        draft.purchaseType != FragmentPurchaseType.stars) {
      return false;
    }

    final text = ctx.message?.text?.trim();
    if (text == null || text.isEmpty) {
      await _reply.sendText(ctx.id, StarsPurchaseText.invalidAmount);
      return true;
    }
    final amount = int.tryParse(text.replaceAll(' ', ''));
    if (amount == null || amount < 50 || amount > 1000000) {
      await _reply.sendText(ctx.id, StarsPurchaseText.invalidAmount);
      return true;
    }

    try {
      final quote = await _pricing.quoteStars(amount);
      final exactPriceRub = await _exchangeRate.convertUsdToRub(quote.price);
      final updated = _flows.applyQuote(
        buyerTelegramId: from.id,
        quote: quote,
        priceRub: exactPriceRub,
      );
      if (updated != null) {
        await _showSelectedQuote(ctx, quote, exactPriceRub.roundedRub);
      }
    } on FragmentApiException catch (error) {
      await _handlePricingFailure(ctx, error);
    } on ExchangeRateException catch (error) {
      await _handleExchangeRateFailure(ctx, error);
    }
    return true;
  }

  Future<void> _showSelectedQuote(
    Context ctx,
    FragmentPriceQuote quote,
    int priceRub,
  ) async {
    await _reply.sendText(
      ctx.id,
      StarsPurchaseText.selected(quote: quote, priceRub: priceRub),
    );
    await _recipientSelection.showChoice(ctx);
  }

  _StarsPackagePrice? _takePackagePriceRub({
    required int buyerTelegramId,
    required StarsPackageSelection selection,
  }) {
    final prices = _priceSessions.take(
      buyerTelegramId: buyerTelegramId,
      generation: selection.generation,
    );
    return prices?[selection.amount];
  }

  Future<Map<int, _StarsPackagePrice>> _loadPackagePricesRub() async {
    final snapshot = await _exchangeRate.getSnapshot();
    final entries = await Future.wait(
      StarsPurchaseCallbacks.packageAmounts.map((amount) async {
        final quote = await _pricing.quoteStars(amount);
        final exactRub = _exchangeRate.convertUsingSnapshot(
          quote.price,
          snapshot,
        );
        return MapEntry(
          amount,
          _StarsPackagePrice(
            quote: quote,
            exactRub: exactRub,
            displayedRub: exactRub.roundedRub,
          ),
        );
      }),
    );
    return Map.fromEntries(entries);
  }

  Future<void> _handlePricingFailure(
    Context ctx,
    FragmentApiException error,
  ) async {
    final buyerTelegramId = ctx.from!.id;
    _flows.cancel(buyerTelegramId);
    _priceSessions.remove(buyerTelegramId);
    BotLog.error(
      'fragment pricing_failed buyer=$buyerTelegramId type=stars '
      'kind=${error.kind.name} status=${error.statusCode ?? 'none'}',
    );
    await _reply.sendText(
      ctx.id,
      FragmentPurchaseResultText.serviceUnavailable,
    );
  }

  Future<void> _handleExchangeRateFailure(
    Context ctx,
    ExchangeRateException error,
  ) async {
    final buyerTelegramId = ctx.from!.id;
    _flows.cancel(buyerTelegramId);
    _priceSessions.remove(buyerTelegramId);
    BotLog.error(
      'fragment pricing_failed buyer=$buyerTelegramId type=stars '
      'exchange_kind=${error.kind.name} status=${error.statusCode ?? 'none'}',
    );
    await _reply.sendText(
      ctx.id,
      FragmentPurchaseResultText.serviceUnavailable,
    );
  }
}

class _StarsPackagePrice {
  const _StarsPackagePrice({
    required this.quote,
    required this.exactRub,
    required this.displayedRub,
  });

  final FragmentPriceQuote quote;
  final RubAmount exactRub;
  final int displayedRub;
}
