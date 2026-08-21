import 'package:ton_dart/ton_dart.dart';

enum TonAddressValidationError { empty, tooLong, invalid, networkMismatch }

class TonAddressValidationException implements Exception {
  const TonAddressValidationException({required this.error});

  final TonAddressValidationError error;
}

class TonAddressValidator {
  const TonAddressValidator({required this.testnet});

  static const maximumInputLength = 128;

  final bool testnet;

  String normalize(String rawAddress) {
    final value = rawAddress.trim();
    if (value.isEmpty) {
      throw const TonAddressValidationException(
        error: TonAddressValidationError.empty,
      );
    }
    if (value.length > maximumInputLength) {
      throw const TonAddressValidationException(
        error: TonAddressValidationError.tooLong,
      );
    }
    try {
      final address = TonAddress(value);
      if (address.isFriendly && address.isTestOnly != testnet) {
        throw const TonAddressValidationException(
          error: TonAddressValidationError.networkMismatch,
        );
      }
      return address.toFriendlyAddress(bounceable: false, testOnly: testnet);
    } on TonAddressValidationException {
      rethrow;
    } catch (_) {
      throw const TonAddressValidationException(
        error: TonAddressValidationError.invalid,
      );
    }
  }
}
