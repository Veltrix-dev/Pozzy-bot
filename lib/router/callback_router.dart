import 'package:pozzy_bot/app/labels/button/mainMenu/callback.dart';
import 'package:pozzy_bot/app/labels/button/profileMenu/profile_callbacks.dart';
import 'package:pozzy_bot/handler/main_menu_handler.dart';
import 'package:televerse/televerse.dart';

class CallbackRouter {
  CallbackRouter({required MainMenuHandler mainMenu}) : _mainMenu = mainMenu;

  final MainMenuHandler _mainMenu;

  Future<void> route(Context ctx) async {
    final data = ctx.callbackQuery?.data?.trim();
    if (data == null || data.isEmpty) return;

    switch (data) {
      case Callback.profile:
        return _mainMenu.onProfile(ctx);
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
