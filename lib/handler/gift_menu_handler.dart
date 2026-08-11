import 'package:pozzy_bot/app/labels/message/gift/gift_menu_text.dart';
import 'package:pozzy_bot/app/labels/message/gift/gift_purchase_text.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/keyboards/gift/gift_callbacks.dart';
import 'package:pozzy_bot/keyboards/gift/gift_catalog_keyboard.dart';
import 'package:pozzy_bot/services/gift/gift_catalog.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_key.dart';
import 'package:televerse/televerse.dart';

class GiftMenuHandler {
  GiftMenuHandler(this._reply);

  final ReplyHandler _reply;

  Future<void> onOpen(Context ctx) async {
    await _reply.sendMenuWithPhoto(
      ctx.id,
      photo: MenuPhotoKey.buyDeleteGift,
      text: GiftMenuText.build(),
      replyMarkup: GiftCatalogKeyboard().markup,
    );
  }

  Future<void> onGiftSelected(Context ctx, String callbackData) async {
    final kind = GiftCallbacks.parse(callbackData);
    if (kind == null) return;

    await _reply.sendText(
      ctx.id,
      GiftPurchaseText.paymentInDevelopment(GiftCatalog.productFor(kind)),
    );
  }
}
