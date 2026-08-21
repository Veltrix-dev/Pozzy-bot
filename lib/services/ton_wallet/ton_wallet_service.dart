import 'dart:async';
import 'dart:convert';

import 'package:blockchain_utils/bip/mnemonic/mnemonic.dart';
import 'package:blockchain_utils/bip/ton/mnemonic/ton_seed_generator.dart';
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/services/ton_api/ton_api_client.dart';
import 'package:pozzy_bot/services/ton_api/ton_api_exception.dart';
import 'package:pozzy_bot/services/ton_api/ton_api_http_provider.dart';
import 'package:pozzy_bot/services/ton_wallet/ton_address_validator.dart';
import 'package:pozzy_bot/services/ton_wallet/ton_wallet_gateway.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:ton_dart/ton_dart.dart';

class TonWalletService implements TonWalletGateway {
  TonWalletService({
    required TonApiClient api,
    required List<String> seedWords,
    required TonAmount feeReserve,
    required bool testnet,
    required int confirmationAttempts,
    required Duration confirmationInterval,
    bool apiConfigured = true,
    bool feeReserveConfigured = true,
  }) : _api = api,
       _seedWords = List<String>.unmodifiable(seedWords),
       _feeReserve = feeReserve,
       _testnet = testnet,
       _confirmationAttempts = confirmationAttempts,
       _confirmationInterval = confirmationInterval,
       _apiConfigured = apiConfigured,
       _feeReserveConfigured = feeReserveConfigured,
       _addressValidator = TonAddressValidator(testnet: testnet);

  factory TonWalletService.fromConfig() {
    final reserveRaw = Config.tonWalletFeeReserveNanoRaw;
    final reserveNano = int.tryParse(reserveRaw);
    final reserveConfigured = reserveNano != null && reserveNano >= 0;
    final provider = TonApiHttpProvider(
      baseUrl: Config.tonApiBaseUrl,
      apiKey: Config.tonApiKey,
      requestTimeout: Duration(seconds: Config.tonApiTimeoutSeconds),
      minimumRequestInterval: Duration(
        milliseconds: Config.tonApiMinRequestIntervalMilliseconds,
      ),
    );
    return TonWalletService(
      api: TonApiClient(provider),
      seedWords: Config.fragmentWalletSeedWords,
      feeReserve: TonAmount.fromNano(
        reserveNano != null && reserveNano >= 0 ? reserveNano : 0,
      ),
      testnet: Config.tonApiTestnet,
      confirmationAttempts: Config.tonWalletConfirmAttempts,
      confirmationInterval: Duration(
        seconds: Config.tonWalletConfirmIntervalSeconds,
      ),
      apiConfigured: Config.tonApiKey.isNotEmpty,
      feeReserveConfigured: reserveConfigured,
    );
  }

  final TonApiClient _api;
  final List<String> _seedWords;
  final TonAmount _feeReserve;
  final bool _testnet;
  final int _confirmationAttempts;
  final Duration _confirmationInterval;
  final bool _apiConfigured;
  final bool _feeReserveConfigured;
  final TonAddressValidator _addressValidator;

  WalletV5R1? _wallet;
  TonPrivateKey? _signer;
  Future<void> _operationChain = Future<void>.value();

  String get walletAddress {
    _initialize();
    return _wallet!.address.toFriendlyAddress(
      bounceable: true,
      testOnly: _testnet,
    );
  }

  @override
  String normalizeAddress(String rawAddress) {
    try {
      return _addressValidator.normalize(rawAddress);
    } on TonAddressValidationException {
      throw const TonApiException(
        kind: TonApiErrorKind.invalidInput,
        message:
            'Recipient TON address is invalid or belongs to another network',
      );
    }
  }

  @override
  Future<TonAmount> getBalance({String? address}) async {
    _ensureApiConfiguration();
    final normalized = address == null
        ? walletAddress
        : normalizeAddress(address);
    BotLog.event('ton balance_request address=${_maskAddress(normalized)}');
    final balance = await _api.getBalanceNano(
      TonAddress(normalized).toRawAddress(),
    );
    if (balance < BigInt.zero || balance > BigInt.from(0x7fffffffffffffff)) {
      throw const TonApiException(
        kind: TonApiErrorKind.invalidResponse,
        message: 'TON API returned an invalid balance',
      );
    }
    final amount = TonAmount.fromNano(balance.toInt());
    BotLog.event(
      'ton balance_received address=${_maskAddress(normalized)} '
      'balance_nano=${amount.nano}',
    );
    return amount;
  }

  @override
  Future<TonWalletSendResult> sendTon({
    required String operationId,
    required String recipientAddress,
    required TonAmount amount,
    String? comment,
    String? payloadBase64,
    required Future<void> Function(TonPreparedTransfer prepared) onPrepared,
  }) {
    return _enqueue(() async {
      _ensureApiConfiguration();
      _initialize();
      if (!_feeReserveConfigured) {
        throw const TonApiException(
          kind: TonApiErrorKind.configuration,
          message: 'TON_WALLET_FEE_RESERVE_NANO is not configured',
        );
      }
      if (amount.isZero) {
        throw const TonApiException(
          kind: TonApiErrorKind.invalidInput,
          message: 'TON amount must be greater than zero',
        );
      }
      if (comment != null && payloadBase64 != null) {
        throw const TonApiException(
          kind: TonApiErrorKind.invalidInput,
          message: 'Comment and payload cannot be used together',
        );
      }
      if (comment != null && utf8.encode(comment).length > 120) {
        throw const TonApiException(
          kind: TonApiErrorKind.invalidInput,
          message: 'TON transfer comment is too long',
        );
      }
      final normalized = normalizeAddress(recipientAddress);
      final destination = TonAddress(normalized);
      final balance = await getBalance();
      final requiredNano = amount.nano + _feeReserve.nano;
      if (balance.nano < requiredNano) {
        throw const TonApiException(
          kind: TonApiErrorKind.insufficientBalance,
          message: 'Hot wallet balance is insufficient',
        );
      }

      await _syncWalletFromChain();
      final body = _buildBody(comment: comment, payloadBase64: payloadBase64);
      final validUntil = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300;
      String signedBoc;
      try {
        signedBoc = await _api.guardRpc(
          () => _wallet!.sendTransfer(
            params: VersionedV5TransferParams.external(
              signer: _signer!,
              messages: [
                OutActionSendMsg(
                  outMessage: TonHelper.internal(
                    destination: destination,
                    amount: BigInt.from(amount.nano),
                    body: body,
                    bounce: false,
                  ),
                ),
              ],
            ),
            rpc: _api.rpc,
            timeout: validUntil,
            action: TonTransactionAction.boc,
          ),
        );
      } on TonApiException {
        rethrow;
      } catch (error) {
        throw TonApiException(
          kind: TonApiErrorKind.invalidInput,
          message: 'TON transfer serialization failed: ${error.runtimeType}',
        );
      }
      final messageHash = _cellHashHex(signedBoc);
      final prepared = TonPreparedTransfer(
        signedBoc: signedBoc,
        messageHash: messageHash,
      );
      await onPrepared(prepared);
      BotLog.event(
        'ton transfer_broadcast operation=$operationId amount_nano=${amount.nano} '
        'recipient=${_maskAddress(normalized)} message_hash=$messageHash',
      );
      await _api.broadcastBoc(signedBoc);
      final confirmation = await _waitForConfirmation(messageHash);
      return TonWalletSendResult(
        status: confirmation.status,
        messageHash: messageHash,
        txHash: confirmation.txHash,
      );
    });
  }

  @override
  Future<TonWalletConfirmation> findConfirmation(String messageHash) async {
    final transaction = await _api.findTransactionByMessageHash(messageHash);
    if (transaction == null) {
      return const TonWalletConfirmation(status: TonWalletSendStatus.pending);
    }
    return TonWalletConfirmation(
      status: transaction.success
          ? TonWalletSendStatus.completed
          : TonWalletSendStatus.onChainFailed,
      txHash: transaction.hash,
    );
  }

  @override
  Future<void> rebroadcast(String signedBoc) => _api.broadcastBoc(signedBoc);

  Future<TonWalletConfirmation> _waitForConfirmation(String messageHash) async {
    for (var attempt = 0; attempt < _confirmationAttempts; attempt++) {
      try {
        final confirmation = await findConfirmation(messageHash);
        if (confirmation.status != TonWalletSendStatus.pending) {
          return confirmation;
        }
      } on TonApiException catch (error) {
        BotLog.error(
          'ton confirmation_failed message_hash=$messageHash '
          'kind=${error.kind.name} status=${error.statusCode ?? 'none'}',
        );
        return const TonWalletConfirmation(status: TonWalletSendStatus.pending);
      }
      if (attempt + 1 < _confirmationAttempts) {
        await Future<void>.delayed(_confirmationInterval);
      }
    }
    return const TonWalletConfirmation(status: TonWalletSendStatus.pending);
  }

  Cell _buildBody({String? comment, String? payloadBase64}) {
    if (payloadBase64 != null) {
      try {
        return Cell.fromBase64(payloadBase64);
      } catch (_) {
        throw const TonApiException(
          kind: TonApiErrorKind.invalidInput,
          message: 'TON transfer payload is invalid',
        );
      }
    }
    return TonHelper.buildMessageBody(comment);
  }

  Future<void> _syncWalletFromChain() async {
    final active = await _api.guardRpc(() => _wallet!.isActive(_api.rpc));
    if (!active) return;
    _wallet = await _api.guardRpc(
      () => WalletV5R1.fromAddress(
        address: _wallet!.address,
        rpc: _api.rpc,
        chain: _testnet ? TonChainId.testnet : TonChainId.mainnet,
      ),
    );
  }

  void _initialize() {
    if (_wallet != null) return;
    if (_seedWords.isEmpty) {
      throw const TonApiException(
        kind: TonApiErrorKind.configuration,
        message: 'FRAGMENT_WALLET_SEED is not configured',
      );
    }
    try {
      final seed = TonSeedGenerator(
        Mnemonic(_seedWords),
      ).generate(validateTonMnemonic: true);
      _signer = TonPrivateKey.fromBytes(seed);
      final chain = _testnet ? TonChainId.testnet : TonChainId.mainnet;
      _wallet = WalletV5R1.create(
        context: V5R1ClientContext(subwalletNumber: 0, chain: chain),
        publicKey: _signer!.toPublicKey().toBytes(),
        chain: chain,
      );
      BotLog.info('ton wallet_ready address=${_maskAddress(walletAddress)}');
    } catch (error) {
      _wallet = null;
      _signer = null;
      throw TonApiException(
        kind: TonApiErrorKind.configuration,
        message: 'TON wallet seed is invalid: ${error.runtimeType}',
      );
    }
  }

  void _ensureApiConfiguration() {
    if (!_apiConfigured) {
      throw const TonApiException(
        kind: TonApiErrorKind.configuration,
        message: 'TONAPI_API_KEY is not configured',
      );
    }
  }

  String _cellHashHex(String signedBoc) {
    final hash = Cell.fromBase64(signedBoc).hash();
    return hash.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _operationChain.then((_) => action());
    _operationChain = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  String _maskAddress(String address) {
    if (address.length <= 12) return '***';
    return '${address.substring(0, 6)}…${address.substring(address.length - 6)}';
  }

  @override
  void close() => _api.close();
}
