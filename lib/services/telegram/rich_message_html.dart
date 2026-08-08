abstract final class RichMessageHtml {
  static String thinking(String innerHtml) => '<tg-thinking>$innerHtml</tg-thinking>';

  static String emojiMarkdown(String emojiId) => '![](tg://emoji?id=$emojiId)';
}