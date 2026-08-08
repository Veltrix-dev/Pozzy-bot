abstract final class HtmlFormat {
  static String escape(String text) => text
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;');

  static String emoji(String emojiId, String fallback) =>
    '<tg-emoji emoji-id="$emojiId">$fallback</tg-emoji>';
    
  static String bold(String text) => '<b>${escape(text)}</b>';
  static String italic(String text) => '<i>${escape(text)}</i>';
  static String underline(String text) => '<u>${escape(text)}</u>';
  static String link(String text, String url) => '<a href="${escape(url)}">${escape(text)}</a>';
  static String code(String text) => '<code>${escape(text)}</code>';
  static String spoiler(String text) => '<span class="tg-spoiler">${escape(text)}</span>';
}