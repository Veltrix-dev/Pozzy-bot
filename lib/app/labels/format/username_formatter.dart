import 'package:pozzy_bot/app/labels/format/html_format.dart';

abstract final class UsernameFormatter {

  static String format(String? username) {
    if (username == null) return '—';
    final trimmed = username.trim();
    if (trimmed.isEmpty) return '—';
    return '@${HtmlFormat.escape(trimmed)}';
  }

  static String optionalLine(String? username) {
    if (username == null || username.trim().isEmpty) return '';
    return 'Username: @${username.trim()}\n';
  }
}
