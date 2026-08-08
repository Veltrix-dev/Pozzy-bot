import 'package:pozzy_bot/app/labels/format/emoji.dart';

abstract class StartMessage {
  static final startMessage = '''
${Emoji.starsPlusTelgram} Добро пожаловать в Pozzy Stars!

<blockquote><i>Здесь вы можете приобрести Telegram Stars, Premium, TON и многое другое по лучшим ценам за рубли и криптовалюту</i>

${Emoji.menu} Управление доступно через меню ниже:</blockquote>
 
''';
}