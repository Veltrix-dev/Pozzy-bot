import 'package:pozzy_bot/app/labels/button/profileMenu/profile_buttons.dart';
import 'package:pozzy_bot/app/labels/button/profileMenu/profile_callbacks.dart';
import 'package:televerse/telegram.dart';

class ReferralKeyboard {
  ReferralKeyboard({
    required this.referralLink,
  });

  final String referralLink;

  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: ProfileButtons.openLink,
          url: referralLink,
        ),
      ],
      [
        InlineKeyboardButton(
          text: ProfileButtons.share,
          url: _shareUrl,
        ),
      ],
      [
        InlineKeyboardButton(
          text: ProfileButtons.referralsList,
          callbackData: ProfileCallbacks.referralsList,
        ),
      ],
    ],
  );

  String get _shareUrl {
    final text = Uri.encodeComponent(
      'Присоединяйся к боту:\n$referralLink',
    );
    return 'https://t.me/share/url?url=${Uri.encodeComponent(referralLink)}&text=$text';
  }
}
