import 'package:pozzy_bot/app/labels/message/mainMenu/start_message.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:televerse/televerse.dart';

class StartHandler {
  StartHandler(this._users, this._reply);

  final UserService _users;
  final ReplyHandler _reply;

  Future<void> onStart(Context ctx)  async {
   final from = ctx.from;
   if(from == null) return;
   
   await _users.getOrCreate(
    telegramId: from.id,
    username: from.username,
   );

   await showMainMenu(ctx.id);
  }

  Future<void> showMainMenu(ChatID chatId) async {
    await _reply.sendMainMenu(chatId, text: StartMessage.startMessage);
  }
}