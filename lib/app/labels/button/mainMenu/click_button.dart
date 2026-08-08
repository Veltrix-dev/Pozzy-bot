import 'package:pozzy_bot/app/labels/format/emoji.dart';
import 'package:pozzy_bot/app/labels/format/html_format.dart';

abstract class ClickButton {

 static final news = ''' 
 В канале публикуются новости проекта, важные обновления и промокоды${Emoji.down}

<blockquote>Также для подписчиков канала регулярно проходят розыгрыши и появляются важные события Telegram:

${HtmlFormat.link('@pozzynft', 'https://t.me/pozzynft')} </blockquote>
 '''; 

 static final chat = '''
${Emoji.lightning}Чат проекта:

<blockquote>Станьте частью нашего сообщества! Здесь вы найдёте помощь, общение и ответы на любые вопросы${Emoji.down}

${HtmlFormat.link('Pozzy Chat', 'https://t.me/+MrCWLm_kBxFlNDE0')}</blockquote>
''';

 static final support = '''
${Emoji.support}Поддержка проекта:

<blockquote>По любым вопросам обращайтесь сюда, ответим в течение 24 часов${Emoji.down} 

${HtmlFormat.link('@Pozzy_manager', 'https://t.me/Pozzy_manager')}</blockquote>
''';


}