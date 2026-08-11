enum FragmentOrderStatus {
  created('created'),
  processing('processing'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  const FragmentOrderStatus(this.databaseValue);

  factory FragmentOrderStatus.fromDatabase(String value) {
    return FragmentOrderStatus.values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => throw FormatException('Unknown order status: $value'),
    );
  }

  final String databaseValue;

  bool get isFinal =>
      this == FragmentOrderStatus.completed ||
      this == FragmentOrderStatus.failed ||
      this == FragmentOrderStatus.cancelled;
}
