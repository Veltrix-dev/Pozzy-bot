abstract final class DurationFormatter {

  static String formatPeriod(DateTime start, {DateTime? now}) {
    final current = (now ?? DateTime.now()).toLocal();
    final startDate = start.toLocal();

    if (current.isBefore(startDate)) {
      return '0 дней';
    }

    int years = current.year - startDate.year;
    DateTime temp = _addMonths(startDate, years * 12);
    if (temp.isAfter(current)) {
      years--;
      temp = _addMonths(startDate, years * 12);
    }

    int months = (current.year - temp.year) * 12 + (current.month - temp.month);
    DateTime startPlusMonths = _addMonths(temp, months);
    if (startPlusMonths.isAfter(current)) {
      months--;
      startPlusMonths = _addMonths(temp, months);
    }

    final days = current.difference(startPlusMonths).inDays;

    final parts = <String>[];

    if (years > 0) {
      parts.add(_pluralize(years, 'год', 'года', 'лет'));
    }
    if (months > 0) {
      parts.add(_pluralize(months, 'месяц', 'месяца', 'месяцев'));
    }
    if (days > 0 || parts.isEmpty) {
      parts.add(_pluralize(days, 'день', 'дня', 'дней'));
    }

    return parts.join(' ');
  }

  static DateTime _addMonths(DateTime date, int monthsToAdd) {
    if (monthsToAdd == 0) return date;

    final totalMonths = date.month + monthsToAdd - 1;
    final newYear = date.year + totalMonths ~/ 12;
    final newMonth = totalMonths % 12 + 1;
    final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = date.day > daysInNewMonth ? daysInNewMonth : date.day;

    return DateTime(
      newYear,
      newMonth,
      newDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  static String _pluralize(int number, String one, String few, String many) {
    final mod10 = number % 10;
    final mod100 = number % 100;

    if (mod100 >= 11 && mod100 <= 19) {
      return '$number $many';
    }
    if (mod10 == 1) {
      return '$number $one';
    }
    if (mod10 >= 2 && mod10 <= 4) {
      return '$number $few';
    }
    return '$number $many';
  }
}
