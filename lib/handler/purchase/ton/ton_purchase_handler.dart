import 'package:pozzy_bot/app/labels/message/purchase/common/fragment_purchase_result_text.dart';
import 'package:pozzy_bot/app/labels/message/purchase/common/fragment_payment_text.dart';
import 'package:pozzy_bot/app/labels/message/purchase/ton/ton_purchase_text.dart';
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/database/models/rub_amount.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/handler/purchase/fragment_purchase_coordinator.dart';
import 'package:pozzy_bot/handler/purchase/recipient/recipient_selection_handler.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/keyboards/ton/ton_amount_keyboard.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_exception.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_purchase_flow_service.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_exception.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_service.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_key.dart';
import 'package:pozzy_bot/services/ton_wallet/ton_address_validator.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/televerse.dart';

class TonPurchaseHandler {
  static const _maximumInputLength = 128;
  static const _maximumPersistedInteger = 0x7fffffffffffffff;

  TonPurchaseHandler({
    required ReplyHandler reply,
    required UserService users,
    required FragmentPricingService pricing,
    required ExchangeRateService exchangeRate,
    required FragmentPurchaseFlowService flows,
    required RecipientSelectionHandler recipientSelection,
    required FragmentPurchaseCoordinator coordinator,
    required TonAddressValidator addressValidator,
    DateTime Function()? clock,
  }) : _reply = reply,
       _users = users,
       _pricing = pricing,
       _exchangeRate = exchangeRate,
       _flows = flows,
       _recipientSelection = recipientSelection,
       _coordinator = coordinator,
       _addressValidator = addressValidator,
       _clock = clock ?? DateTime.now;

  final ReplyHandler _reply;
  final UserService _users;
  final FragmentPricingService _pricing;
  final ExchangeRateService _exchangeRate;
  final FragmentPurchaseFlowService _flows;
  final RecipientSelectionHandler _recipientSelection;
  final FragmentPurchaseCoordinator _coordinator;
  final TonAddressValidator _addressValidator;
  final DateTime Function() _clock;
  final Map<int, Object> _destinationRequests = {};

  Future<void> onOpen(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;
    if (_coordinator.isBusy(from.id)) return;
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    _destinationRequests.remove(from.id);
    _flows.cancel(from.id);
    await _reply.sendMenuWithPhoto(
      ctx.id,
      photo: MenuPhotoKey.buyTon,
      text: TonPurchaseText.menu,
      replyMarkup: TonAmountKeyboard().markup,
    );
  }

  Future<void> onTelegramAccount(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;
    if (_coordinator.isBusy(from.id)) return;
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    final requestToken = Object();
    _destinationRequests[from.id] = requestToken;
    _flows.cancel(from.id);
    try {
      final rate = await _resolveTonRate();
      if (!_isCurrentDestinationRequest(from.id, requestToken)) return;
      _flows.startAwaitingAmount(
        buyerTelegramId: from.id,
        purchaseType: FragmentPurchaseType.ton,
        tonUsdRate: rate.usd,
        tonRubRate: rate.rub,
        tonUsdRubRateMicros: rate.usdRubRateMicros,
        tonRateExpiresAt: _clock().toUtc().add(
          Duration(seconds: Config.tonRateSessionTtlSeconds),
        ),
        tonDestination: TonPurchaseDestination.telegramAccount,
      );
      await _reply.sendText(
        ctx.id,
        TonPurchaseText.telegramAccount(rate.rub),
        replyMarkup: TonAmountKeyboard().amountMarkup,
      );
    } on FragmentApiException catch (error) {
      if (!_isCurrentDestinationRequest(from.id, requestToken)) return;
      await _handlePricingFailure(ctx, error);
    } on ExchangeRateException catch (error) {
      if (!_isCurrentDestinationRequest(from.id, requestToken)) return;
      await _handleExchangeRateFailure(ctx, error);
    } finally {
      if (_isCurrentDestinationRequest(from.id, requestToken)) {
        _destinationRequests.remove(from.id);
      }
    }
  }

  Future<void> onWallet(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;
    if (_coordinator.isBusy(from.id)) return;
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    final requestToken = Object();
    _destinationRequests[from.id] = requestToken;
    _flows.cancel(from.id);
    try {
      final rate = await _resolveTonRate();
      if (!_isCurrentDestinationRequest(from.id, requestToken)) return;
      _flows.startAwaitingAmount(
        buyerTelegramId: from.id,
        purchaseType: FragmentPurchaseType.ton,
        tonUsdRate: rate.usd,
        tonRubRate: rate.rub,
        tonUsdRubRateMicros: rate.usdRubRateMicros,
        tonRateExpiresAt: _clock().toUtc().add(
          Duration(seconds: Config.tonRateSessionTtlSeconds),
        ),
        tonDestination: TonPurchaseDestination.wallet,
      );
      await _reply.sendText(
        ctx.id,
        TonPurchaseText.tonWallet(rate.rub),
        replyMarkup: TonAmountKeyboard().amountMarkup,
      );
    } on FragmentApiException catch (error) {
      if (!_isCurrentDestinationRequest(from.id, requestToken)) return;
      await _handlePricingFailure(ctx, error);
    } on ExchangeRateException catch (error) {
      if (!_isCurrentDestinationRequest(from.id, requestToken)) return;
      await _handleExchangeRateFailure(ctx, error);
    } finally {
      if (_isCurrentDestinationRequest(from.id, requestToken)) {
        _destinationRequests.remove(from.id);
      }
    }
  }

  Future<bool> onAnyMessage(Context ctx) async {
    final from = ctx.from;
    if (from == null) return false;
    final draft = _flows.find(from.id);
    if (draft == null || draft.purchaseType != FragmentPurchaseType.ton) {
      return false;
    }

    if (draft.step == FragmentPurchaseFlowStep.awaitingTonWallet) {
      return _handleWalletAddress(ctx, draft);
    }
    if (draft.step != FragmentPurchaseFlowStep.awaitingAmount) return false;

    final text = ctx.message?.text?.trim();
    if (text != null && text.length > _maximumInputLength) {
      await _reply.sendText(ctx.id, TonPurchaseText.invalidAmount);
      return true;
    }
    final amount = text == null ? null : _parseAmount(text);
    if (amount == null ||
        amount.nano < TonAmount.nanoPerTon ||
        amount.nano > _maximumPersistedInteger) {
      await _reply.sendText(ctx.id, TonPurchaseText.invalidAmount);
      return true;
    }

    try {
      final tonUsdRate = draft.tonUsdRate;
      final tonRubRate = draft.tonRubRate;
      final tonUsdRubRateMicros = draft.tonUsdRubRateMicros;
      final expiresAt = draft.tonRateExpiresAt;
      if (tonUsdRate == null ||
          tonRubRate == null ||
          tonUsdRubRateMicros == null ||
          expiresAt == null ||
          !_clock().toUtc().isBefore(expiresAt)) {
        final refreshedRate = await _resolveTonRate();
        _flows.startAwaitingAmount(
          buyerTelegramId: from.id,
          purchaseType: FragmentPurchaseType.ton,
          tonUsdRate: refreshedRate.usd,
          tonRubRate: refreshedRate.rub,
          tonUsdRubRateMicros: refreshedRate.usdRubRateMicros,
          tonRateExpiresAt: _clock().toUtc().add(
            Duration(seconds: Config.tonRateSessionTtlSeconds),
          ),
          tonDestination: draft.tonDestination,
        );
        await _reply.sendText(
          ctx.id,
          TonPurchaseText.rateExpired(refreshedRate.rub),
          replyMarkup: TonAmountKeyboard().amountMarkup,
        );
        return true;
      }
      final quote = _pricing.quoteTonAtRate(amount, tonUsdRate);
      final priceRub = _exchangeRate.convertUsdToRubAtFixedRate(
        quote.price,
        tonUsdRubRateMicros,
      );
      if (quote.price.micros > _maximumPersistedInteger ||
          priceRub.micros > _maximumPersistedInteger) {
        await _reply.sendText(ctx.id, TonPurchaseText.invalidAmount);
        return true;
      }
      if (draft.tonDestination == TonPurchaseDestination.wallet) {
        final updated = _flows.applyTonWalletQuote(
          buyerTelegramId: from.id,
          quote: quote,
          priceRub: priceRub,
        );
        if (updated != null) {
          await _reply.sendText(
            ctx.id,
            TonPurchaseText.walletAmountSelected(
              quote: quote,
              tonRubRate: tonRubRate,
              priceRub: priceRub,
            ),
          );
        }
        return true;
      }
      final updated = _flows.applyQuote(
        buyerTelegramId: from.id,
        quote: quote,
        priceRub: priceRub,
      );
      if (updated != null) {
        await _reply.sendText(
          ctx.id,
          TonPurchaseText.selected(
            quote: quote,
            tonRubRate: tonRubRate,
            priceRub: priceRub,
          ),
        );
        await _recipientSelection.showChoice(ctx);
      }
    } on FragmentApiException catch (error) {
      await _handlePricingFailure(ctx, error);
    } on ExchangeRateException catch (error) {
      await _handleExchangeRateFailure(ctx, error);
    }
    return true;
  }

  Future<bool> _handleWalletAddress(
    Context ctx,
    FragmentPurchaseFlowDraft draft,
  ) async {
    final rawAddress = ctx.message?.text;
    if (rawAddress == null || rawAddress.trim().isEmpty) {
      await _reply.sendText(ctx.id, TonPurchaseText.invalidWalletAddress);
      return true;
    }
    final candidate = rawAddress.trim();
    if (candidate.length > TonAddressValidator.maximumInputLength) {
      await _reply.sendText(ctx.id, TonPurchaseText.invalidWalletAddress);
      return true;
    }
    if (_parseAmount(candidate) != null) {
      await _reply.sendText(ctx.id, TonPurchaseText.walletAddressPrompt);
      return true;
    }
    late final String normalizedAddress;
    try {
      normalizedAddress = _addressValidator.normalize(rawAddress);
    } on TonAddressValidationException {
      await _reply.sendText(ctx.id, TonPurchaseText.invalidWalletAddress);
      return true;
    }
    final applied = _flows.applyTonWalletAddress(
      draft.buyerTelegramId,
      normalizedAddress: normalizedAddress,
      now: _clock(),
    );
    if (applied.outcome == TonWalletAddressApplyOutcome.invalidState) {
      _flows.cancel(draft.buyerTelegramId);
      await _reply.sendText(
        ctx.id,
        FragmentPurchaseResultText.serviceUnavailable,
      );
      return true;
    }
    if (applied.outcome == TonWalletAddressApplyOutcome.quoteExpired) {
      _flows.cancel(draft.buyerTelegramId);
      await _reply.sendText(ctx.id, FragmentPaymentText.quoteExpired);
      return true;
    }
    _flows.cancel(draft.buyerTelegramId);
    await _reply.sendText(ctx.id, FragmentPaymentText.inDevelopment);
    return true;
  }

  TonAmount? _parseAmount(String raw) {
    try {
      return TonAmount.parse(raw.replaceAll(',', '.'));
    } on FormatException {
      return null;
    }
  }

  bool _isCurrentDestinationRequest(int buyerTelegramId, Object token) =>
      identical(_destinationRequests[buyerTelegramId], token);

  Future<_TonRate> _resolveTonRate() async {
    final usd = await _pricing.getTonUsdRateWithMarkup();
    final exchangeRate = await _exchangeRate.getSnapshot();
    final rub = _exchangeRate.convertUsdToRubAtFixedRate(
      usd,
      exchangeRate.rateMicros,
    );
    return _TonRate(
      usd: usd,
      rub: rub,
      usdRubRateMicros: exchangeRate.rateMicros,
    );
  }

  Future<void> _handlePricingFailure(
    Context ctx,
    FragmentApiException error,
  ) async {
    final buyerTelegramId = ctx.from!.id;
    _flows.cancel(buyerTelegramId);
    BotLog.error(
      'fragment pricing_failed buyer=$buyerTelegramId type=ton '
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
    BotLog.error(
      'fragment pricing_failed buyer=$buyerTelegramId type=ton '
      'exchange_kind=${error.kind.name} status=${error.statusCode ?? 'none'}',
    );
    await _reply.sendText(
      ctx.id,
      FragmentPurchaseResultText.serviceUnavailable,
    );
  }
}

class _TonRate {
  const _TonRate({
    required this.usd,
    required this.rub,
    required this.usdRubRateMicros,
  });

  final UsdAmount usd;
  final RubAmount rub;
  final int usdRubRateMicros;
}
