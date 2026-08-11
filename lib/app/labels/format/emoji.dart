import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/app/labels/format/html_format.dart';

abstract final class Emoji {
  static String get stars => HtmlFormat.emoji(PremiumEmojiIds.stars, '⭐');
  static String get starsPlusTelgram =>
      HtmlFormat.emoji(PremiumEmojiIds.telegramStars, '⭐');
  static String get ton => HtmlFormat.emoji(PremiumEmojiIds.ton, '💎');
  static String get premium => HtmlFormat.emoji(PremiumEmojiIds.premium, '⭐');
  static String get profile => HtmlFormat.emoji(PremiumEmojiIds.profile, '👤');
  static String get profile2 =>
      HtmlFormat.emoji(PremiumEmojiIds.profile2, '👤');
  static String get profile3 =>
      HtmlFormat.emoji(PremiumEmojiIds.profile3, '👤');
  static String get deletedGifts =>
      HtmlFormat.emoji(PremiumEmojiIds.remotegifts, '🧸');
  static String get promoCode =>
      HtmlFormat.emoji(PremiumEmojiIds.promoCode, '⭐');
  static String get checks => HtmlFormat.emoji(PremiumEmojiIds.check, '💰');
  static String get communication =>
      HtmlFormat.emoji(PremiumEmojiIds.communication, '🎤');
  static String get news => HtmlFormat.emoji(PremiumEmojiIds.news, '🎤');
  static String get support => HtmlFormat.emoji(PremiumEmojiIds.support, '📞');
  static String get lightning =>
      HtmlFormat.emoji(PremiumEmojiIds.lightning, '⚡');
  static String get down => HtmlFormat.emoji(PremiumEmojiIds.down, '⚡');
  static String get menu => HtmlFormat.emoji(PremiumEmojiIds.menu, '🎲');
  static String get earned => HtmlFormat.emoji(PremiumEmojiIds.earned, '💰');
  static String get balance => HtmlFormat.emoji(PremiumEmojiIds.balance, '💰');
  static String get statistics =>
      HtmlFormat.emoji(PremiumEmojiIds.statistics, '📊');
  static String get time => HtmlFormat.emoji(PremiumEmojiIds.time, '⏱️');
  static String get boxstars =>
      HtmlFormat.emoji(PremiumEmojiIds.boxstars, '📦');
  static String get link => HtmlFormat.emoji(PremiumEmojiIds.link, '🔗');
  static String get referrals =>
      HtmlFormat.emoji(PremiumEmojiIds.referrals, '👥');
  static String get referralsBalance =>
      HtmlFormat.emoji(PremiumEmojiIds.referralsBalance, '👥');
  static String get send => HtmlFormat.emoji(PremiumEmojiIds.send, '✈️');
  static String get back => HtmlFormat.emoji(PremiumEmojiIds.back, '🔙');
  static String get sad => HtmlFormat.emoji(PremiumEmojiIds.sad, '😢');
  static String get scull => HtmlFormat.emoji(PremiumEmojiIds.scull, '💀');
  static String get checkMark =>
      HtmlFormat.emoji(PremiumEmojiIds.checkMark, '✅');
}
