import 'package:pozzy_bot/app/labels/button/adminMenu/admin_callback.dart';
import 'package:pozzy_bot/app/labels/button/mainMenu/callback.dart';
import 'package:pozzy_bot/app/labels/button/purchase/premium/premium_purchase_callbacks.dart';
import 'package:pozzy_bot/app/labels/button/purchase/recipient/recipient_selection_callbacks.dart';
import 'package:pozzy_bot/app/labels/button/purchase/stars/stars_purchase_callbacks.dart';
import 'package:pozzy_bot/app/labels/button/purchase/ton/ton_purchase_callbacks.dart';
import 'package:pozzy_bot/app/labels/button/profileMenu/profile_callbacks.dart';
import 'package:pozzy_bot/handler/gift_menu_handler.dart';
import 'package:pozzy_bot/handler/admin/admin_panel_handler.dart';
import 'package:pozzy_bot/handler/main_menu_handler.dart';
import 'package:pozzy_bot/handler/purchase/fragment_purchase_coordinator.dart';
import 'package:pozzy_bot/handler/purchase/premium/premium_purchase_handler.dart';
import 'package:pozzy_bot/handler/purchase/recipient/recipient_selection_handler.dart';
import 'package:pozzy_bot/handler/purchase/stars/stars_purchase_handler.dart';
import 'package:pozzy_bot/handler/purchase/ton/ton_purchase_handler.dart';
import 'package:pozzy_bot/keyboards/gift/gift_callbacks.dart';
import 'package:televerse/televerse.dart';

class CallbackRouter {
  CallbackRouter({
    required MainMenuHandler mainMenu,
    required GiftMenuHandler giftMenu,
    required StarsPurchaseHandler starsPurchase,
    required PremiumPurchaseHandler premiumPurchase,
    required TonPurchaseHandler tonPurchase,
    required RecipientSelectionHandler recipientSelection,
    required FragmentPurchaseCoordinator purchaseCoordinator,
    required AdminPanelHandler adminPanel,
  }) : _mainMenu = mainMenu,
       _giftMenu = giftMenu,
       _starsPurchase = starsPurchase,
       _premiumPurchase = premiumPurchase,
       _tonPurchase = tonPurchase,
       _recipientSelection = recipientSelection,
       _purchaseCoordinator = purchaseCoordinator,
       _adminPanel = adminPanel;

  final MainMenuHandler _mainMenu;
  final GiftMenuHandler _giftMenu;
  final StarsPurchaseHandler _starsPurchase;
  final PremiumPurchaseHandler _premiumPurchase;
  final TonPurchaseHandler _tonPurchase;
  final RecipientSelectionHandler _recipientSelection;
  final FragmentPurchaseCoordinator _purchaseCoordinator;
  final AdminPanelHandler _adminPanel;

  Future<void> route(Context ctx) async {
    final data = ctx.callbackQuery?.data?.trim();
    if (data == null || data.isEmpty) return;

    if (AdminCallback.isAdminCallback(data)) {
      _purchaseCoordinator.cancelForNavigation(ctx);
      return _adminPanel.onCallback(ctx, data);
    }

    _adminPanel.cancelForUser(ctx.from?.id);

    if (data.startsWith(StarsPurchaseCallbacks.prefix)) {
      return _routeStarsPurchase(ctx, data);
    }
    if (data.startsWith(PremiumPurchaseCallbacks.prefix)) {
      return _routePremiumPurchase(ctx, data);
    }
    if (data.startsWith(TonPurchaseCallbacks.prefix)) {
      return _routeTonPurchase(ctx, data);
    }
    if (data.startsWith(RecipientSelectionCallbacks.prefix)) {
      return _routeRecipientSelection(ctx, data);
    }
    switch (data) {
      case Callback.buyStars:
        return _starsPurchase.onOpen(ctx);
      case Callback.buyPremium:
        return _premiumPurchase.onOpen(ctx);
      case Callback.buyTon:
        return _tonPurchase.onOpen(ctx);
    }

    _purchaseCoordinator.cancelForNavigation(ctx);

    if (data.startsWith(GiftCallbacks.prefix)) {
      return _giftMenu.onGiftSelected(ctx, data);
    }

    switch (data) {
      case Callback.mainMenu:
        return _mainMenu.onMainMenu(ctx);
      case Callback.profile:
        return _mainMenu.onProfile(ctx);
      case Callback.deletedGifts:
        return _giftMenu.onOpen(ctx);
      case Callback.news:
        return _mainMenu.onNews(ctx);
      case Callback.chatProject:
        return _mainMenu.onChat(ctx);
      case Callback.support:
        return _mainMenu.onSupport(ctx);
      case ProfileCallbacks.referrals:
        return _mainMenu.onReferrals(ctx);
      case ProfileCallbacks.referralsList:
        return _mainMenu.onReferralsList(ctx);
      case ProfileCallbacks.statistics:
        return _mainMenu.onStatistics(ctx);
    }
  }

  Future<void> _routeStarsPurchase(Context ctx, String callbackData) async {
    final selection = StarsPurchaseCallbacks.packageSelection(callbackData);
    if (selection != null) {
      return _starsPurchase.onSelectPackage(ctx, selection);
    }
    if (callbackData == StarsPurchaseCallbacks.customAmount) {
      return _starsPurchase.onCustomAmount(ctx);
    }
    return _starsPurchase.onExpiredPrice(ctx);
  }

  Future<void> _routePremiumPurchase(Context ctx, String callbackData) async {
    final selection = PremiumPurchaseCallbacks.durationSelection(callbackData);
    if (selection != null) {
      return _premiumPurchase.onSelectDuration(ctx, selection);
    }
    return _premiumPurchase.onExpiredPrice(ctx);
  }

  Future<void> _routeTonPurchase(Context ctx, String callbackData) async {
    switch (callbackData) {
      case TonPurchaseCallbacks.telegramAccount:
        return _tonPurchase.onTelegramAccount(ctx);
      case TonPurchaseCallbacks.wallet:
        return _tonPurchase.onWallet(ctx);
    }
  }

  Future<void> _routeRecipientSelection(
    Context ctx,
    String callbackData,
  ) async {
    switch (callbackData) {
      case RecipientSelectionCallbacks.toSelf:
        return _recipientSelection.onToSelf(ctx);
      case RecipientSelectionCallbacks.toOther:
        return _recipientSelection.onToOther(ctx);
      case RecipientSelectionCallbacks.back:
        return _recipientSelection.onBack(ctx);
    }
  }
}
