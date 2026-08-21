class RubAmount implements Comparable<RubAmount> {
  const RubAmount.fromMicros(this.micros) : assert(micros >= 0);

  factory RubAmount.parse(String value) {
    return RubAmount.fromMicros(_parseFixed(value, 6, 'RUB'));
  }

  static const microsPerRub = 1000000;
  static const zero = RubAmount.fromMicros(0);

  final int micros;

  bool get isZero => micros == 0;

  int get roundedRub => (micros + microsPerRub ~/ 2) ~/ microsPerRub;

  String toDecimalString() => _formatFixed(micros, 6);

  @override
  int compareTo(RubAmount other) => micros.compareTo(other.micros);

  @override
  bool operator ==(Object other) =>
      other is RubAmount && other.micros == micros;

  @override
  int get hashCode => micros.hashCode;

  @override
  String toString() => '${toDecimalString()} RUB';
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
