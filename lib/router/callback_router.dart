import 'package:pozzy_bot/app/labels/button/mainMenu/callback.dart';
import 'package:pozzy_bot/app/labels/button/profileMenu/profile_callbacks.dart';
import 'package:pozzy_bot/handler/gift_menu_handler.dart';
import 'package:pozzy_bot/handler/main_menu_handler.dart';
import 'package:pozzy_bot/keyboards/gift/gift_callbacks.dart';
import 'package:televerse/televerse.dart';

class CallbackRouter {
  CallbackRouter({
    required MainMenuHandler mainMenu,
    required GiftMenuHandler giftMenu,
  }) : _mainMenu = mainMenu,
       _giftMenu = giftMenu;

  final MainMenuHandler _mainMenu;
  final GiftMenuHandler _giftMenu;

  Future<void> route(Context ctx) async {
    final data = ctx.callbackQuery?.data?.trim();
    if (data == null || data.isEmpty) return;

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
}
