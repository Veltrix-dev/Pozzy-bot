import 'dart:math';

import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';

enum FragmentPurchaseFlowStep {
  awaitingAmount,
  awaitingRecipientChoice,
  awaitingOtherRecipient,
  resolvingRecipient,
  purchasing,
}

class FragmentPurchaseFlowDraft {
  const FragmentPurchaseFlowDraft({
    required this.buyerTelegramId,
    required this.purchaseType,
    required this.step,
    required this.idempotencyKey,
    this.quote,
    this.resumeStep,
  });

  final int buyerTelegramId;
  final FragmentPurchaseType purchaseType;
  final FragmentPurchaseFlowStep step;
  final String idempotencyKey;
  final FragmentPriceQuote? quote;
  final FragmentPurchaseFlowStep? resumeStep;

  FragmentPurchaseFlowDraft copyWith({
    FragmentPurchaseFlowStep? step,
    FragmentPriceQuote? quote,
    FragmentPurchaseFlowStep? resumeStep,
    bool clearResumeStep = false,
  }) {
    return FragmentPurchaseFlowDraft(
      buyerTelegramId: buyerTelegramId,
      purchaseType: purchaseType,
      step: step ?? this.step,
      idempotencyKey: idempotencyKey,
      quote: quote ?? this.quote,
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
  }) {
    final draft = FragmentPurchaseFlowDraft(
      buyerTelegramId: buyerTelegramId,
      purchaseType: purchaseType,
      step: FragmentPurchaseFlowStep.awaitingAmount,
      idempotencyKey: _newIdempotencyKey(buyerTelegramId),
    );
    _drafts[buyerTelegramId] = draft;
    return draft;
  }

  FragmentPurchaseFlowDraft startAwaitingRecipient({
    required int buyerTelegramId,
    required FragmentPriceQuote quote,
  }) {
    final draft = FragmentPurchaseFlowDraft(
      buyerTelegramId: buyerTelegramId,
      purchaseType: quote.purchaseType,
      step: FragmentPurchaseFlowStep.awaitingRecipientChoice,
      idempotencyKey: _newIdempotencyKey(buyerTelegramId),
      quote: quote,
    );
    _drafts[buyerTelegramId] = draft;
    return draft;
  }

  FragmentPurchaseFlowDraft? applyQuote({
    required int buyerTelegramId,
    required FragmentPriceQuote quote,
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
      clearResumeStep: true,
    );
    _drafts[buyerTelegramId] = updated;
    return updated;
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

  bool beginPurchase(int buyerTelegramId, {required String idempotencyKey}) {
    final draft = _drafts[buyerTelegramId];
    if (draft == null ||
        draft.idempotencyKey != idempotencyKey ||
        draft.step != FragmentPurchaseFlowStep.resolvingRecipient) {
      return false;
    }
    _drafts[buyerTelegramId] = draft.copyWith(
      step: FragmentPurchaseFlowStep.purchasing,
    );
    return true;
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
