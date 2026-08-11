class TonAmount implements Comparable<TonAmount> {
  const TonAmount.fromNano(this.nano) : assert(nano >= 0);

  factory TonAmount.parse(String input) {
    final value = input.trim();
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(value);
    if (match == null) {
      throw const FormatException('Invalid TON amount');
    }

    final whole = int.parse(match.group(1)!);
    var fraction = match.group(2) ?? '';
    if (fraction.length > 9) {
      final discarded = fraction.substring(9);
      if (discarded.contains(RegExp(r'[1-9]'))) {
        throw const FormatException('TON amount has more than 9 decimals');
      }
      fraction = fraction.substring(0, 9);
    }
    final padded = fraction.padRight(9, '0');
    final nano = whole * nanoPerTon + (padded.isEmpty ? 0 : int.parse(padded));
    return TonAmount.fromNano(nano);
  }

  static const nanoPerTon = 1000000000;
  static const zero = TonAmount.fromNano(0);

  final int nano;

  bool get isZero => nano == 0;

  String toDecimalString() {
    final whole = nano ~/ nanoPerTon;
    final fraction = (nano % nanoPerTon).toString().padLeft(9, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
  }

  @override
  int compareTo(TonAmount other) => nano.compareTo(other.nano);

  @override
  bool operator ==(Object other) => other is TonAmount && other.nano == nano;

  @override
  int get hashCode => nano.hashCode;

  @override
  String toString() => '${toDecimalString()} TON';
}
