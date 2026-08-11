class UsdAmount implements Comparable<UsdAmount> {
  const UsdAmount.fromMicros(this.micros) : assert(micros >= 0);

  factory UsdAmount.parse(String value) {
    return UsdAmount.fromMicros(_parseFixed(value, 6, 'USD'));
  }

  factory UsdAmount.fromLegacyDouble(double value) {
    return UsdAmount.parse(value.toString());
  }

  static const zero = UsdAmount.fromMicros(0);

  final int micros;

  bool get isZero => micros == 0;

  UsdAmount multiply(int multiplier) {
    if (multiplier < 0) {
      throw ArgumentError.value(multiplier, 'multiplier');
    }
    return UsdAmount.fromMicros(micros * multiplier);
  }

  UsdAmount multiplyRatio(int numerator, int denominator) {
    if (numerator < 0 || denominator <= 0) {
      throw ArgumentError('Invalid ratio $numerator/$denominator');
    }
    final product = micros * numerator;
    final result = product ~/ denominator;
    final roundedUp = product % denominator == 0 ? result : result + 1;
    return UsdAmount.fromMicros(roundedUp);
  }

  UsdAmount multiplyFraction(String fraction, {bool roundToCents = false}) {
    final ratio = _parseFixed(fraction, 6, 'fraction');
    final product = micros * ratio;
    var result = (product + 500000) ~/ 1000000;
    if (roundToCents) {
      result = ((result + 5000) ~/ 10000) * 10000;
    }
    return UsdAmount.fromMicros(result);
  }

  UsdAmount percentage(String percent) {
    final scaledPercent = _parseFixed(percent, 6, 'percent');
    final denominator = 100000000;
    final product = micros * scaledPercent;
    return UsdAmount.fromMicros((product + denominator ~/ 2) ~/ denominator);
  }

  UsdAmount add(UsdAmount other) {
    return UsdAmount.fromMicros(micros + other.micros);
  }

  String toDecimalString() => _formatFixed(micros, 6);

  double toLegacyDouble() => micros / 1000000;

  @override
  int compareTo(UsdAmount other) => micros.compareTo(other.micros);

  @override
  bool operator ==(Object other) =>
      other is UsdAmount && other.micros == micros;

  @override
  int get hashCode => micros.hashCode;

  @override
  String toString() => '${toDecimalString()} USD';
}

int _parseFixed(String input, int scale, String unit) {
  final value = input.trim();
  final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(value);
  if (match == null) {
    throw FormatException('Invalid $unit amount');
  }

  final whole = int.parse(match.group(1)!);
  var fraction = match.group(2) ?? '';
  if (fraction.length > scale) {
    final discarded = fraction.substring(scale);
    if (discarded.contains(RegExp(r'[1-9]'))) {
      throw FormatException('$unit amount has more than $scale decimals');
    }
    fraction = fraction.substring(0, scale);
  }
  final padded = fraction.padRight(scale, '0');
  return whole * _powerOfTen(scale) + (padded.isEmpty ? 0 : int.parse(padded));
}

String _formatFixed(int units, int scale) {
  final divisor = _powerOfTen(scale);
  final whole = units ~/ divisor;
  final fraction = (units % divisor).toString().padLeft(scale, '0');
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
}

int _powerOfTen(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value;
}
