abstract final class TelegramUsername {
  static final RegExp _pattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]{4,31}$');

  static String? normalize(String? raw) {
    if (raw == null) return null;

    var value = raw.trim();
    if (value.startsWith('@')) value = value.substring(1).trim();
    if (!_pattern.hasMatch(value)) return null;
    return value.toLowerCase();
  }
}
