DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

final Map<int, Set<DateTime>> _cache = {};

Set<DateTime> brazilianHolidays(int year) {
  return _cache.putIfAbsent(year, () {
    final easter = easterSunday(year);
    DateTime shift(int days) => DateTime(
      easter.year,
      easter.month,
      easter.day,
    ).add(Duration(days: days));
    return {
      DateTime(year, 1, 1),
      shift(-48),
      shift(-47),
      shift(-2),
      DateTime(year, 4, 21),
      DateTime(year, 5, 1),
      shift(60),
      DateTime(year, 9, 7),
      DateTime(year, 10, 12),
      DateTime(year, 11, 2),
      DateTime(year, 11, 15),
      DateTime(year, 12, 25),
    };
  });
}

bool isBrazilianHoliday(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return brazilianHolidays(date.year).contains(day);
}
