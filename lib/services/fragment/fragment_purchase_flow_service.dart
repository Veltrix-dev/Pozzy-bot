import 'dart:math';

import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/database/models/rub_amount.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';

enum FragmentPurchaseFlowStep {
  awaitingAmount,
  awaitingTonWallet,
  awaitingRecipientChoice,
  awaitingOtherRecipient,
  resolvingRecipient,
  purchasing,
}

enum FragmentPurchaseBeginOutcome { started, invalidState, quoteExpired }

class FragmentPurchaseBeginResult {
  const FragmentPurchaseBeginResult({required this.outcome, this.draft});

  final FragmentPurchaseBeginOutcome outcome;
  final FragmentPurchaseFlowDraft? draft;
}

enum TonWalletAddressApplyOutcome { applied, invalidState, quoteExpired }

class TonWalletAddressApplyResult {
  const TonWalletAddressApplyResult({required this.outcome, this.draft});

  final TonWalletAddressApplyOutcome outcome;
  final FragmentPurchaseFlowDraft? draft;
}

enum TonPurchaseDestination { telegramAccount, wallet }

class FragmentPurchaseFlowDraft {
  const FragmentPurchaseFlowDraft({
    required this.buyerTelegramId,
    required this.purchaseType,
    required this.step,
    required this.idempotencyKey,
    this.quote,
    this.priceRub,
    this.tonUsdRate,
    this.tonRubRate,
    this.tonUsdRubRateMicros,
    this.tonRateExpiresAt,
    this.tonDestination,
    this.tonWalletAddress,
    this.resumeStep,
  });

  final int buyerTelegramId;
  final FragmentPurchaseType purchaseType;
  final FragmentPurchaseFlowStep step;
  final String idempotencyKey;
  final FragmentPriceQuote? quote;
  final RubAmount? priceRub;
  final UsdAmount? tonUsdRate;
  final RubAmount? tonRubRate;
  final int? tonUsdRubRateMicros;
  final DateTime? tonRateExpiresAt;
  final TonPurchaseDestination? tonDestination;
  final String? tonWalletAddress;
  final FragmentPurchaseFlowStep? resumeStep;

  FragmentPurchaseFlowDraft copyWith({
    FragmentPurchaseFlowStep? step,
    FragmentPriceQuote? quote,
    RubAmount? priceRub,
    UsdAmount? tonUsdRate,
    RubAmount? tonRubRate,
    int? tonUsdRubRateMicros,
    DateTime? tonRateExpiresAt,
    TonPurchaseDestination? tonDestination,
    String? tonWalletAddress,
    FragmentPurchaseFlowStep? resumeStep,
    bool clearResumeStep = false,
  }) {
    return FragmentPurchaseFlowDraft(
      buyerTelegramId: buyerTelegramId,
      purchaseType: purchaseType,
      step: step ?? this.step,
      idempotencyKey: idempotencyKey,
      quote: quote ?? this.quote,
      priceRub: priceRub ?? this.priceRub,
      tonUsdRate: tonUsdRate ?? this.tonUsdRate,
      tonRubRate: tonRubRate ?? this.tonRubRate,
      tonUsdRubRateMicros: tonUsdRubRateMicros ?? this.tonUsdRubRateMicros,
      tonRateExpiresAt: tonRateExpiresAt ?? this.tonRateExpiresAt,
      tonDestination: tonDestination ?? this.tonDestination,
      tonWalletAddress: tonWalletAddress ?? this.tonWalletAddress,
      resumeStep: clearResumeStep ? null : resumeStep ?? this.resumeStep,
    );
  }
}

class FragmentPurchaseFlowService {
  final Map<int, FragmentPurchaseFlowDraft> _drafts = {};
  final Random _random = Random.secure();

  FragmentPurchaseFlowDraft? find(int buyerTelegramId) =>
      _drafts[buyerTelegramId];

  bool hasActiveFlow(int buyerTelegramId) =>
      _drafts.containsKey(buyerTelegramId);

  FragmentPurchaseFlowDraft startAwaitingAmount({
    required int buyerTelegramId,
    required FragmentPurchaseType purchaseType,
    UsdAmount? tonUsdRate,
    RubAmount? tonRubRate,
    int? tonUsdRubRateMicros,
    DateTime? tonRateExpiresAt,
    TonPurchaseDestination? tonDestination,
  }) {
    final draft = FragmentPurchaseFlowDraft(
      buyerTelegramId: buyerTelegramId,
      purchaseType: purchaseType,
      step: FragmentPurchaseFlowStep.awaitingAmount,
      idempotencyKey: _newIdempotencyKey(buyerTelegramId),
      tonUsdRate: tonUsdRate,
      tonRubRate: tonRubRate,
      tonUsdRubRateMicros: tonUsdRubRateMicros,
      tonRateExpiresAt: tonRateExpiresAt?.toUtc(),
      tonDestination: tonDestination,
    );
    _drafts[buyerTelegramId] = draft;
    return draft;
  }

  FragmentPurchaseFlowDraft startAwaitingRecipient({
    required int buyerTelegramId,
    required FragmentPriceQuote quote,
    RubAmount? priceRub,
  }) {
    final draft = FragmentPurchaseFlowDraft(
      buyerTelegramId: buyerTelegramId,
      purchaseType: quote.purchaseType,
      step: FragmentPurchaseFlowStep.awaitingRecipientChoice,
      idempotencyKey: _newIdempotencyKey(buyerTelegramId),
      quote: quote,
      priceRub: priceRub,
    );
    _drafts[buyerTelegramId] = draft;
    return draft;
  }

  FragmentPurchaseFlowDraft? applyQuote({
    required int buyerTelegramId,
    required FragmentPriceQuote quote,
    RubAmount? priceRub,
  }) {
    final draft = _drafts[buyerTelegramId];
    if (draft == null ||
        draft.step != FragmentPurchaseFlowStep.awaitingAmount ||
        draft.purchaseType != quote.purchaseType) {
      return null;
    }
    final updated = draft.copyWith(
      step: FragmentPurchaseFlowStep.awaitingRecipientChoice,
      quote: quote,
      priceRub: priceRub,
      clearResumeStep: true,
    );
    _drafts[buyerTelegramId] = updated;
    return updated;
  }

  FragmentPurchaseFlowDraft? applyTonWalletQuote({
    required int buyerTelegramId,
    required FragmentPriceQuote quote,
    required RubAmount priceRub,
  }) {
    final draft = _drafts[buyerTelegramId];
    if (draft == null ||
        draft.step != FragmentPurchaseFlowStep.awaitingAmount ||
        draft.purchaseType != FragmentPurchaseType.ton ||
        draft.tonDestination != TonPurchaseDestination.wallet) {
      return null;
    }
    final updated = draft.copyWith(
      step: FragmentPurchaseFlowStep.awaitingTonWallet,
      quote: quote,
      priceRub: priceRub,
      clearResumeStep: true,
    );
    _drafts[buyerTelegramId] = updated;
    return updated;
  }

  TonWalletAddressApplyResult applyTonWalletAddress(
    int buyerTelegramId, {
    required String normalizedAddress,
    required DateTime now,
  }) {
    final draft = _drafts[buyerTelegramId];
    if (draft == null ||
        draft.step != FragmentPurchaseFlowStep.awaitingTonWallet ||
        draft.purchaseType != FragmentPurchaseType.ton ||
        draft.tonDestination != TonPurchaseDestination.wallet ||
        draft.quote == null ||
        draft.priceRub == null ||
        normalizedAddress.isEmpty) {
      return const TonWalletAddressApplyResult(
        outcome: TonWalletAddressApplyOutcome.invalidState,
      );
    }
    final expiresAt = draft.tonRateExpiresAt;
    if (expiresAt == null || !now.toUtc().isBefore(expiresAt)) {
      return TonWalletAddressApplyResult(
        outcome: TonWalletAddressApplyOutcome.quoteExpired,
        draft: draft,
      );
    }
    final updated = draft.copyWith(tonWalletAddress: normalizedAddress);
    _drafts[buyerTelegramId] = updated;
    return TonWalletAddressApplyResult(
      outcome: TonWalletAddressApplyOutcome.applied,
      draft: updated,
    );
  }

  bool awaitOtherRecipient(int buyerTelegramId) {
    final draft = _drafts[buyerTelegramId];
    if (draft == null ||
        draft.step != FragmentPurchaseFlowStep.awaitingRecipientChoice) {
      return false;
    }
    _drafts[buyerTelegramId] = draft.copyWith(
      step: FragmentPurchaseFlowStep.awaitingOtherRecipient,
      clearResumeStep: true,
    );
    return true;
  }

  bool returnToRecipientChoice(int buyerTelegramId) {
    final draft = _drafts[buyerTelegramId];
    if (draft == null ||
        draft.step != FragmentPurchaseFlowStep.awaitingOtherRecipient) {
      return false;
    }
    _drafts[buyerTelegramId] = draft.copyWith(
      step: FragmentPurchaseFlowStep.awaitingRecipientChoice,
      clearResumeStep: true,
    );
    return true;
  }

  FragmentPurchaseFlowDraft? beginRecipientResolution(
    int buyerTelegramId, {
    required FragmentPurchaseFlowStep expectedStep,
  }) {
    final draft = _drafts[buyerTelegramId];
    if (draft == null || draft.step != expectedStep || draft.quote == null) {
      return null;
    }
    final updated = draft.copyWith(
      step: FragmentPurchaseFlowStep.resolvingRecipient,
      resumeStep: expectedStep,
    );
    _drafts[buyerTelegramId] = updated;
    return updated;
  }

  FragmentPurchaseBeginResult beginPurchase(
    int buyerTelegramId, {
    required String idempotencyKey,
    required DateTime now,
  }) {
    final draft = _drafts[buyerTelegramId];
    if (draft == null ||
        draft.idempotencyKey != idempotencyKey ||
        draft.step != FragmentPurchaseFlowStep.resolvingRecipient) {
      return const FragmentPurchaseBeginResult(
        outcome: FragmentPurchaseBeginOutcome.invalidState,
      );
    }
    if (draft.purchaseType == FragmentPurchaseType.ton) {
      final expiresAt = draft.tonRateExpiresAt;
      if (expiresAt == null || !now.toUtc().isBefore(expiresAt)) {
        return FragmentPurchaseBeginResult(
          outcome: FragmentPurchaseBeginOutcome.quoteExpired,
          draft: draft,
        );
      }
    }
    final updated = draft.copyWith(step: FragmentPurchaseFlowStep.purchasing);
    _drafts[buyerTelegramId] = updated;
    return FragmentPurchaseBeginResult(
      outcome: FragmentPurchaseBeginOutcome.started,
      draft: updated,
    );
  }

  bool restoreAfterFailure(
    int buyerTelegramId, {
    required String idempotencyKey,
  }) {
    final draft = _drafts[buyerTelegramId];
    final resumeStep = draft?.resumeStep;
    if (draft == null ||
        draft.idempotencyKey != idempotencyKey ||
        resumeStep == null) {
      return false;
    }
    _drafts[buyerTelegramId] = draft.copyWith(
      step: resumeStep,
      clearResumeStep: true,
    );
    return true;
  }

  bool cancel(int buyerTelegramId) => _drafts.remove(buyerTelegramId) != null;

  String _newIdempotencyKey(int buyerTelegramId) {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    final suffix = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'ui:$buyerTelegramId:'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}:$suffix';
  }
}
