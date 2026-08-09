import 'package:pozzy_bot/app/labels/button/mainMenu/click_button.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/handler/profile_menu_handler.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_key.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:televerse/televerse.dart';

class MainMenuHandler {
  MainMenuHandler(this._reply, this._users, {required ProfileMenuHandler profileMenu}) : _profileMenu = profileMenu;

  final ReplyHandler _reply;
  final UserService _users;
  final ProfileMenuHandler _profileMenu;

  Future<void> onNews(Context ctx) async {
    await _reply.sendMenuWithPhoto(
      ctx.id,
      photo: MenuPhotoKey.newsProject,
      text: ClickButton.news,
    );
  }

  Future<void> onChat(Context ctx) async {
    await _reply.sendMenuWithPhoto(
      ctx.id,
      photo: MenuPhotoKey.chatProject,
      text: ClickButton.chat,
    );
  }

  Future<void> onSupport(Context ctx) async {
    await _reply.sendMenuWithPhoto(
      ctx.id,
      photo: MenuPhotoKey.support,
      text: ClickButton.support,
    );
  }

  Future<void> onProfile(Context ctx) async {
    return _profileMenu.onProfile(ctx);
  }
}
