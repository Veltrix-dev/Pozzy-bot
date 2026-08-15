import 'package:pozzy_bot/app/labels/format/emoji.dart';

abstract final class RecipientSelectionText {
  static final chooseRecipient = 'Выберите получателя:';
  static const askUsername = 'Введите @username получателя:';

  static const toSelfButtonText = 'Себе';
  static const toOtherButtonText = 'Другому';

  static const backButtonText = 'Назад';

  static final invalidUsername = 'Некорректный username${Emoji.scull}';

  static final recipientNotFound =
      'Пользователь не найден${Emoji.scull}\nПроверьте username и отправьте его снова';
  static final serviceUnavailable =
      'Не удалось проверить получателя${Emoji.scull}';
  static final wrongMessageType = '${Emoji.exclamationMark2}Ожидается username';
  static final usernameMissing = 'У вашего аккаунта нет username${Emoji.sad}';
  static const checking = 'Проверяем получателя...';

  static String confirmed(String username) =>
      'Получатель @$username\nОформляем покупку...';
}
