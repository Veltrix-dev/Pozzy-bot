import 'package:pozzy_bot/database/models/ton_amount.dart';

class TonPreparedTransfer {
  const TonPreparedTransfer({
    required this.signedBoc,
    required this.messageHash,
  });

  final String signedBoc;
  final String messageHash;
}

enum TonWalletSendStatus { completed, pending, onChainFailed }

class TonWalletSendResult {
  const TonWalletSendResult({
    required this.status,
    required this.messageHash,
    this.txHash,
  });

  final TonWalletSendStatus status;
  final String messageHash;
  final String? txHash;
}

class TonWalletConfirmation {
  const TonWalletConfirmation({required this.status, this.txHash});

  final TonWalletSendStatus status;
  final String? txHash;
}

abstract interface class TonWalletGateway {
  String normalizeAddress(String rawAddress);

  Future<TonAmount> getBalance({String? address});

  Future<TonWalletSendResult> sendTon({
    required String operationId,
    required String recipientAddress,
    required TonAmount amount,
    String? comment,
    String? payloadBase64,
    required Future<void> Function(TonPreparedTransfer prepared) onPrepared,
  });

  Future<TonWalletConfirmation> findConfirmation(String messageHash);

  Future<void> rebroadcast(String signedBoc);

  void close();
}
