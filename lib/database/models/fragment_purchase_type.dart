enum FragmentPurchaseType {
  stars('stars'),
  premium('premium'),
  ton('ton');

  const FragmentPurchaseType(this.databaseValue);

  factory FragmentPurchaseType.fromDatabase(String value) {
    return FragmentPurchaseType.values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => throw FormatException('Unknown purchase type: $value'),
    );
  }

  final String databaseValue;
}
