import 'package:pozzy_bot/app/labels/button/purchase/stars/stars_purchase_callbacks.dart';
import 'package:pozzy_bot/app/labels/message/purchase/common/fragment_purchase_result_text.dart';
import 'package:pozzy_bot/app/labels/message/purchase/stars/stars_purchase_text.dart';
import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/handler/purchase/recipient/recipient_selection_handler.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/keyboards/stars/stars_amount_keyboard.dart';
import 'package:pozzy_bot/keyboards/stars/stars_purchase_keyboard.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_exception.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_exception.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_purchase_flow_service.dart';
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
  }) : _reply = reply,
       _users = users,
       _pricing = pricing,
       _exchangeRate = exchangeRate,
       _flows = flows,
       _recipientSelection = recipientSelection;

  final ReplyHandler _reply;
  final UserService _users;
  final FragmentPricingService _pricing;
  final ExchangeRateService _exchangeRate;
  final FragmentPurchaseFlowService _flows;
  final RecipientSelectionHandler _recipientSelection;
  final Map<int, Map<int, int>> _packagePricesRubByBuyer = {};

  Future<void> onOpen(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;
    _flows.cancel(from.id);
    _packagePricesRubByBuyer.remove(from.id);
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    try {
      final packagePricesRub = await _loadPackagePricesRub();
      _packagePricesRubByBuyer[from.id] = packagePricesRub;
      await _reply.sendMenuWithPhoto(
        ctx.id,
        photo: MenuPhotoKey.buyStars,
        text: StarsPurchaseText.menu,
        replyMarkup: StarsPurchaseKeyboard(
          packagePricesRub: packagePricesRub,
        ).markup,
      );
    } on FragmentApiException catch (error) {
      await _handlePricingFailure(ctx, error);
    } on ExchangeRateException catch (error) {
      await _handleExchangeRateFailure(ctx, error);
    }
  }

  Future<void> onSelectPackage(Context ctx, int amount) async {
    final from = ctx.from;
    if (from == null) return;
    _flows.cancel(from.id);
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    try {
      final priceRub = await _takePackagePriceRub(
        buyerTelegramId: from.id,
        amount: amount,
      );
      final quote = await _pricing.quoteStars(amount);
      _flows.startAwaitingRecipient(buyerTelegramId: from.id, quote: quote);
      await _showSelectedQuote(ctx, quote, priceRub);
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
    _packagePricesRubByBuyer.remove(from.id);
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
      final priceRub = await _convertQuoteToRub(quote);
      final updated = _flows.applyQuote(buyerTelegramId: from.id, quote: quote);
      if (updated != null) await _showSelectedQuote(ctx, quote, priceRub);
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

  Future<int> _convertQuoteToRub(FragmentPriceQuote quote) async {
    final priceRub = await _exchangeRate.convertUsdToRub(
      quote.price.toLegacyDouble(),
    );
    return priceRub.round();
  }

  Future<int> _takePackagePriceRub({
    required int buyerTelegramId,
    required int amount,
  }) async {
    final displayedPrices = _packagePricesRubByBuyer.remove(buyerTelegramId);
    final displayedPrice = displayedPrices?[amount];
    if (displayedPrice != null) return displayedPrice;

    final currentPrices = await _loadPackagePricesRub();
    final currentPrice = currentPrices[amount];
    if (currentPrice == null) {
      throw StateError('Missing RUB price for $amount Stars');
    }
    return currentPrice;
  }

  Future<Map<int, int>> _loadPackagePricesRub() async {
    final entries = await Future.wait(
      StarsPurchaseCallbacks.packageAmounts.map((amount) async {
        final quote = await _pricing.quoteStars(amount);
        return MapEntry(amount, await _convertQuoteToRub(quote));
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
    _packagePricesRubByBuyer.remove(buyerTelegramId);
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
    _packagePricesRubByBuyer.remove(buyerTelegramId);
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
