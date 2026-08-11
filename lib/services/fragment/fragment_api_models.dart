import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';

class FragmentRecipient {
  const FragmentRecipient({
    required this.name,
    required this.username,
    this.photoUrl,
    this.recipientId,
  });

  final String name;
  final String username;
  final String? photoUrl;
  final String? recipientId;
}

class FragmentApiHealth {
  const FragmentApiHealth({
    required this.healthy,
    required this.version,
    required this.cookieExists,
    required this.cookieValid,
  });

  final bool healthy;
  final String version;
  final bool cookieExists;
  final bool cookieValid;
}

class FragmentPurchaseReceipt {
  const FragmentPurchaseReceipt({
    required this.purchaseType,
    required this.user,
    required this.username,
    required this.tonPaid,
    required this.deliveredUnits,
    this.externalReference,
  });

  final FragmentPurchaseType purchaseType;
  final String user;
  final String username;
  final TonAmount tonPaid;
  final int deliveredUnits;
  final String? externalReference;

  Map<String, Object?> toJson() {
    return {
      'purchase_type': purchaseType.databaseValue,
      'user': user,
      'username': username,
      'ton_paid': tonPaid.toDecimalString(),
      'delivered_units': deliveredUnits,
      'external_reference': externalReference,
    };
  }
}
