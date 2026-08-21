import 'dart:math';

class PriceMenuSessionStore<T> {
  PriceMenuSessionStore({
    required Duration ttl,
    DateTime Function()? clock,
    Random? random,
    int maximumSessions = 5000,
  }) : _ttl = _validateTtl(ttl),
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure(),
       _maximumSessions = _validateMaximumSessions(maximumSessions);

  final Duration _ttl;
  final DateTime Function() _clock;
  final Random _random;
  final int _maximumSessions;
  final Map<int, _PriceMenuSession<T>> _sessions = {};
  final Map<int, String> _loadTokens = {};

  int get length => _sessions.length;

  String beginLoad(int buyerTelegramId) {
    remove(buyerTelegramId);
    _removeExpired();
    final token = _newToken();
    _loadTokens[buyerTelegramId] = token;
    return token;
  }

  String? completeLoad({
    required int buyerTelegramId,
    required String version,
    required T value,
  }) {
    if (_loadTokens[buyerTelegramId] != version) return null;
    _loadTokens.remove(buyerTelegramId);
    _removeExpired();
    if (_sessions.length >= _maximumSessions) {
      final oldest = _sessions.entries.reduce(
        (first, second) =>
            first.value.expiresAt.isBefore(second.value.expiresAt)
            ? first
            : second,
      );
      _sessions.remove(oldest.key);
    }
    final generation = _newToken();
    _sessions[buyerTelegramId] = _PriceMenuSession(
      generation: generation,
      value: value,
      expiresAt: _clock().toUtc().add(_ttl),
    );
    return generation;
  }

  bool failLoad(int buyerTelegramId, String version) {
    if (_loadTokens[buyerTelegramId] != version) return false;
    _loadTokens.remove(buyerTelegramId);
    remove(buyerTelegramId);
    return true;
  }

  T? take({required int buyerTelegramId, required String generation}) {
    final session = _sessions[buyerTelegramId];
    if (session == null) return null;
    final expired = !_clock().toUtc().isBefore(session.expiresAt);
    if (expired) {
      _sessions.remove(buyerTelegramId);
      return null;
    }
    if (session.generation != generation) return null;
    _sessions.remove(buyerTelegramId);
    return session.value;
  }

  void remove(int buyerTelegramId) {
    _sessions.remove(buyerTelegramId);
    _loadTokens.remove(buyerTelegramId);
  }

  String _newToken() => _random.nextInt(0x7fffffff).toRadixString(36);

  void _removeExpired() {
    final now = _clock().toUtc();
    _sessions.removeWhere((_, session) => !now.isBefore(session.expiresAt));
  }
}

class _PriceMenuSession<T> {
  const _PriceMenuSession({
    required this.generation,
    required this.value,
    required this.expiresAt,
  });

  final String generation;
  final T value;
  final DateTime expiresAt;
}

Duration _validateTtl(Duration ttl) {
  if (ttl <= Duration.zero) throw ArgumentError.value(ttl, 'ttl');
  return ttl;
}

int _validateMaximumSessions(int maximumSessions) {
  if (maximumSessions <= 0) {
    throw ArgumentError.value(maximumSessions, 'maximumSessions');
  }
  return maximumSessions;
}
