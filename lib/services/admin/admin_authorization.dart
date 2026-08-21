import 'package:pozzy_bot/config/config.dart';

class AdminAuthorization {
  AdminAuthorization({Set<int>? adminTelegramIds})
    : _adminTelegramIds = Set.unmodifiable(
        adminTelegramIds ?? Config.initialAdminTelegramIds,
      );

  final Set<int> _adminTelegramIds;

  bool isAdmin(int? telegramId) =>
      telegramId != null && _adminTelegramIds.contains(telegramId);

  List<int> get adminTelegramIds {
    final ids = _adminTelegramIds.toList()..sort();
    return List.unmodifiable(ids);
  }
}
