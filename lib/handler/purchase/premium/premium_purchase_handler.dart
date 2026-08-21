import 'dart:math';

import 'package:pozzy_bot/app/labels/button/purchase/premium/premium_purchase_callbacks.dart';
import 'package:pozzy_bot/app/labels/message/purchase/common/fragment_purchase_result_text.dart';
import 'package:pozzy_bot/app/labels/message/purchase/premium/premium_purchase_text.dart';
import 'package:pozzy_bot/handler/purchase/fragment_purchase_coordinator.dart';
import 'package:pozzy_bot/handler/purchase/recipient/recipient_selection_handler.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/keyboards/premium/premium_purchase_keyboard.dart';
import 'package:pozzy_bot/database/models/rub_amount.dart';
import 'package:pozzy_bot/config/config.dart';
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

class PremiumPurchaseHandler {
  PremiumPurchaseHandler({
    required ReplyHandler reply,
    required UserService users,
    required FragmentPricingService pricing,
    required ExchangeRateService exchangeRate,
    required FragmentPurchaseFlowService flows,
    required RecipientSelectionHandler recipientSelection,
    required FragmentPurchaseCoordinator coordinator,
    Duration? menuPriceTtl,
    DateTime Function()? clock,
    Random? random,
  }) : _reply = reply,
       _users = users,
       _pricing = pricing,
       _exchangeRate = exchangeRate,
       _flows = flows,
       _recipientSelection = recipientSelection,
       _coordinator = coordinator,
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
  final FragmentPurchaseCoordinator _coordinator;
  final PriceMenuSessionStore<Map<int, _PremiumDurationPrice>> _priceSessions;

  Future<void> onOpen(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;
    if (_coordinator.isBusy(from.id)) return;
    _flows.cancel(from.id);
    final requestVersion = _priceSessions.beginLoad(from.id);
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    try {
      final durationPricesRub = await _loadDurationPricesRub();
      final generation = _priceSessions.completeLoad(
        buyerTelegramId: from.id,
        version: requestVersion,
        value: durationPricesRub,
      );
      if (generation == null) return;
      await _reply.sendMenuWithPhoto(
        ctx.id,
        photo: MenuPhotoKey.buyPremium,
        text: PremiumPurchaseText.menu,
        replyMarkup: PremiumPurchaseKeyboard(
          durationPricesRub: durationPricesRub.map(
            (months, price) => MapEntry(months, price.displayedRub),
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

  Future<void> onSelectDuration(
    Context ctx,
    PremiumDurationSelection selection,
  ) async {
    final from = ctx.from;
    if (from == null) return;
    if (_coordinator.isBusy(from.id)) return;
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    try {
      final durationPrice = _takeDurationPriceRub(
        buyerTelegramId: from.id,
        selection: selection,
      );
      if (durationPrice == null) {
        await _reply.sendText(ctx.id, FragmentPurchaseResultText.priceExpired);
        return;
      }
      _flows.startAwaitingRecipient(
        buyerTelegramId: from.id,
        quote: durationPrice.quote,
        priceRub: durationPrice.exactRub,
      );
      await _reply.sendText(
        ctx.id,
        PremiumPurchaseText.selected(
          quote: durationPrice.quote,
          priceRub: durationPrice.displayedRub,
        ),
      );
      await _recipientSelection.showChoice(ctx);
    } on FragmentApiException catch (error) {
      await _handlePricingFailure(ctx, error);
    } on ExchangeRateException catch (error) {
      await _handleExchangeRateFailure(ctx, error);
    }
  }

  Future<void> onExpiredPrice(Context ctx) {
    return _reply.sendText(ctx.id, FragmentPurchaseResultText.priceExpired);
  }

  _PremiumDurationPrice? _takeDurationPriceRub({
    required int buyerTelegramId,
    required PremiumDurationSelection selection,
  }) {
    final prices = _priceSessions.take(
      buyerTelegramId: buyerTelegramId,
      generation: selection.generation,
    );
    return prices?[selection.months];
  }

  Future<Map<int, _PremiumDurationPrice>> _loadDurationPricesRub() async {
    final snapshot = await _exchangeRate.getSnapshot();
    final entries = await Future.wait(
      [3, 6, 12].map((months) async {
        final quote = _pricing.quotePremium(months);
        final exactRub = _exchangeRate.convertUsingSnapshot(
          quote.price,
          snapshot,
        );
        return MapEntry(
          months,
          _PremiumDurationPrice(
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
      'fragment pricing_failed buyer=$buyerTelegramId type=premium '
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
      'fragment pricing_failed buyer=$buyerTelegramId type=premium '
      'exchange_kind=${error.kind.name} status=${error.statusCode ?? 'none'}',
    );
    await _reply.sendText(
      ctx.id,
      FragmentPurchaseResultText.serviceUnavailable,
    );
  }
}

class _PremiumDurationPrice {
  const _PremiumDurationPrice({
    required this.quote,
    required this.exactRub,
    required this.displayedRub,
  });

  final FragmentPriceQuote quote;
  final RubAmount exactRub;
  final int displayedRub;
}
