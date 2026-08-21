import 'dart:async';
import 'dart:io';

import 'package:blockchain_utils/exception/exception/rpc_error.dart';
import 'package:http/http.dart' as http;
import 'package:pozzy_bot/services/ton_api/ton_api_exception.dart';
import 'package:pozzy_bot/services/ton_api/ton_api_http_provider.dart';
import 'package:ton_dart/ton_dart.dart';

class TonApiTransaction {
  const TonApiTransaction({required this.hash, required this.success});

  final String hash;
  final bool success;
}

class TonApiClient {
  TonApiClient(this._provider) : rpc = TonProvider(_provider);

  final TonApiHttpProvider _provider;
  final TonProvider rpc;

  Future<BigInt> getBalanceNano(String address) {
    return _guard(
      () async => (await rpc.request(TonApiGetAccount(address))).balance,
    );
  }

  Future<void> broadcastBoc(String signedBoc) {
    return _guard(() async {
      await rpc.request(
        TonApiSendBlockchainMessage(batch: const [], boc: signedBoc),
      );
    }, requestMayHaveBeenAccepted: true);
  }

  Future<TonApiTransaction?> findTransactionByMessageHash(
    String messageHash,
  ) async {
    try {
      final transaction = await rpc.request(
        TonApiGetBlockchainTransactionByMessageHash(messageHash),
      );
      return TonApiTransaction(
        hash: transaction.hash,
        success: transaction.success,
      );
    } on RPCError catch (error) {
      if (_statusCode(error) == 404 ||
          error.message.toLowerCase().contains('not found')) {
        return null;
      }
      throw _mapError(error, requestMayHaveBeenAccepted: false);
    } catch (error) {
      throw _mapError(error, requestMayHaveBeenAccepted: false);
    }
  }

  Future<T> _guard<T>(
    Future<T> Function() action, {
    bool requestMayHaveBeenAccepted = false,
  }) async {
    try {
      return await action();
    } catch (error) {
      throw _mapError(
        error,
        requestMayHaveBeenAccepted: requestMayHaveBeenAccepted,
      );
    }
  }

  Future<T> guardRpc<T>(Future<T> Function() action) => _guard(action);

  TonApiException _mapError(
    Object error, {
    required bool requestMayHaveBeenAccepted,
  }) {
    if (error is TonApiException) {
      if (!requestMayHaveBeenAccepted || error.executionUncertain) return error;
      return TonApiException(
        kind: error.kind,
        message: error.message,
        statusCode: error.statusCode,
        executionUncertain:
            error.kind == TonApiErrorKind.server || error.statusCode == null,
      );
    }
    if (error is TimeoutException) {
      return TonApiException(
        kind: TonApiErrorKind.timeout,
        message: 'TON API request timed out',
        executionUncertain: requestMayHaveBeenAccepted,
      );
    }
    if (error is SocketException || error is http.ClientException) {
      return TonApiException(
        kind: TonApiErrorKind.network,
        message: 'TON API network request failed',
        executionUncertain: requestMayHaveBeenAccepted,
      );
    }
    if (error is RPCError) {
      final status = _statusCode(error);
      final kind = status == 401 || status == 403
          ? TonApiErrorKind.unauthorized
          : status == 429
          ? TonApiErrorKind.rateLimit
          : status != null && status >= 500
          ? TonApiErrorKind.server
          : status != null && status >= 400
          ? TonApiErrorKind.rejected
          : TonApiErrorKind.unknown;
      return TonApiException(
        kind: kind,
        message: error.message,
        statusCode: status,
        executionUncertain:
            requestMayHaveBeenAccepted && (status == null || status >= 500),
      );
    }
    if (error is FormatException || error is TypeError) {
      return const TonApiException(
        kind: TonApiErrorKind.invalidResponse,
        message: 'TON API returned an invalid response',
      );
    }
    return TonApiException(
      kind: TonApiErrorKind.unknown,
      message: error.toString(),
      executionUncertain: requestMayHaveBeenAccepted,
    );
  }

  int? _statusCode(RPCError error) => error.statusCode ?? error.errorCode;

  void close() => _provider.close();
}
