String isoDate(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

DateTime parseIsoDate(String value) {
  final parts = value.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String fmtDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String fmtDateIso(String iso) => fmtDate(parseIsoDate(iso));

String fmtMoney(int cents) {
  final negative = cents < 0;
  final value = cents.abs();
  final reais = value ~/ 100;
  final frac = (value % 100).toString().padLeft(2, '0');
  final groups = reais.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );
  return '${negative ? '-' : ''}R\$ $groups,$frac';
}

String fmtRate(int bps) {
  final whole = bps ~/ 100;
  final frac = (bps.abs() % 100).toString().padLeft(2, '0');
  return '$whole,$frac%';
}

int? parseMoney(String raw) {
  var text = raw.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (text.isEmpty) return null;
  if (text.contains(',') && text.contains('.')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else if (text.contains(',')) {
    text = text.replaceAll(',', '.');
  }
  final value = double.tryParse(text);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}

int? parsePercentBps(String raw) {
  final text = raw.trim().replaceAll('%', '').replaceAll(',', '.');
  if (text.isEmpty) return null;
  final value = double.tryParse(text);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}

String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

String fmtPhone(String digits) {
  final clean = digitsOnly(digits);
  if (clean.length == 11) {
    return '(${clean.substring(0, 2)}) ${clean.substring(2, 7)}-${clean.substring(7)}';
  }
  if (clean.length == 10) {
    return '(${clean.substring(0, 2)}) ${clean.substring(2, 6)}-${clean.substring(6)}';
  }
  return clean;
}

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime addMonths(DateTime date, int months) {
  final target = date.month + months;
  final year = date.year + (target - 1) ~/ 12;
  final month = (target - 1) % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = date.day > lastDay ? lastDay : date.day;
  return DateTime(year, month, day);
}
