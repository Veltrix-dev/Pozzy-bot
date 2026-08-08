import 'package:pozzy_bot/app/labels/button/mainMenu/callback.dart';
import 'package:pozzy_bot/handler/main_menu_handler.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:televerse/televerse.dart';

class CallbackRouter {
CallbackRouter({
  required UserService users,
  required MainMenuHandler mainMenu
}) : _users = users,
     _mainMenu = mainMenu;

final UserService _users;
final MainMenuHandler _mainMenu;

Future<void> route(Context ctx) async {
  final data = ctx.callbackQuery?.data?.trim();
  if(data == null || data.isEmpty) return;

  switch(data) {
    case Callback.news:
    return _mainMenu.onNews(ctx);
    case Callback.chatProject:
    return _mainMenu.onChat(ctx);
    case Callback.support:
    return _mainMenu.onSupport(ctx);
  }
}

}