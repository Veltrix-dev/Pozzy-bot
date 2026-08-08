import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/app/labels/format/html_format.dart';

abstract final class Emoji {
  static String get stars => HtmlFormat.emoji(PremiumEmojiIds.stars, '⭐'); 
  static String get starsPlusTelgram => HtmlFormat.emoji(PremiumEmojiIds.telegramStars, '⭐');
  static String get ton => HtmlFormat.emoji(PremiumEmojiIds.ton, '💎');
  static String get premium => HtmlFormat.emoji(PremiumEmojiIds.premium, '⭐');
  static String get profile => HtmlFormat.emoji(PremiumEmojiIds.profile, '👤');
  static String get deletedGifts => HtmlFormat.emoji(PremiumEmojiIds.remotegifts, '🧸');
  static String get promoCode => HtmlFormat.emoji(PremiumEmojiIds.promoCode, '⭐');
  static String get checks => HtmlFormat.emoji(PremiumEmojiIds.check, '💰');
  static String get communication => HtmlFormat.emoji(PremiumEmojiIds.communication, '🎤');
  static String get news => HtmlFormat.emoji(PremiumEmojiIds.news, '🎤');
  static String get support => HtmlFormat.emoji(PremiumEmojiIds.support, '📞');
  static String get lightning => HtmlFormat.emoji(PremiumEmojiIds.lightning, '⚡');
  static String get down => HtmlFormat.emoji(PremiumEmojiIds.down, '⚡');
  
  static String get menu => HtmlFormat.emoji(PremiumEmojiIds.menu, '🎲');
 
  
  
}