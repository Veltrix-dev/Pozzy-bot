abstract final class StarsPurchaseCallbacks {
  static const prefix = 'purchase:stars:';
  static const packageAmounts = [50, 100, 150, 250, 500, 1000, 2500];
  static const stars50 = '${prefix}50';
  static const stars100 = '${prefix}100';
  static const stars150 = '${prefix}150';
  static const stars250 = '${prefix}250';
  static const stars500 = '${prefix}500';
  static const stars1000 = '${prefix}1000';
  static const stars2500 = '${prefix}2500';
  static const customAmount = '${prefix}custom';

  static int? packageAmount(String callbackData) => switch (callbackData) {
    stars50 => 50,
    stars100 => 100,
    stars150 => 150,
    stars250 => 250,
    stars500 => 500,
    stars1000 => 1000,
    stars2500 => 2500,
    _ => null,
  };

  static String packageCallback(int amount) => '$prefix$amount';
}
