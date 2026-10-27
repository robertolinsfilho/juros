import 'dart:math' as math;

import 'holidays.dart';
import '../format.dart';

enum ContractMode { amortizacao, apenasJuros }

enum RateMode { porParcela, total }

enum Frequency { diario, semanal, dezDias, quinzenal, mensal, nDias, personalizado }

extension ContractModeLabel on ContractMode {
  String get code => switch (this) {
    ContractMode.amortizacao => 'amortizacao',
    ContractMode.apenasJuros => 'apenas_juros',
  };

  String get label => switch (this) {
    ContractMode.amortizacao => 'Parcelado (abate o capital)',
    ContractMode.apenasJuros => 'Juros + capital no final',
  };

  static ContractMode parse(String code) {
    return code == 'apenas_juros'
        ? ContractMode.apenasJuros
        : ContractMode.amortizacao;
  }
}

extension RateModeLabel on RateMode {
  String get code => switch (this) {
    RateMode.porParcela => 'por_parcela',
    RateMode.total => 'total',
  };

  String get label => switch (this) {
    RateMode.porParcela => 'Por parcela',
    RateMode.total => 'Total do contrato',
  };

  static RateMode parse(String code) {
    return code == 'total' ? RateMode.total : RateMode.porParcela;
  }
}

extension FrequencyLabel on Frequency {
  String get code => switch (this) {
    Frequency.diario => 'diario',
    Frequency.semanal => 'semanal',
    Frequency.dezDias => 'dez_dias',
    Frequency.quinzenal => 'quinzenal',
    Frequency.mensal => 'mensal',
    Frequency.nDias => 'n_dias',
    Frequency.personalizado => 'personalizado',
  };

  String get label => switch (this) {
    Frequency.diario => 'Diário (1 dia)',
    Frequency.semanal => 'Semanal (7 dias)',
    Frequency.dezDias => 'A cada 10 dias',
    Frequency.quinzenal => 'Quinzenal (15 dias)',
    Frequency.mensal => 'Mensal',
    Frequency.nDias => 'A cada N dias',
    Frequency.personalizado => 'Personalizado',
  };

  static Frequency parse(String code) {
    return switch (code) {
      'diario' => Frequency.diario,
      'semanal' => Frequency.semanal,
      'dez_dias' => Frequency.dezDias,
      'quinzenal' => Frequency.quinzenal,
      'n_dias' => Frequency.nDias,
      'personalizado' => Frequency.personalizado,
      _ => Frequency.mensal,
    };
  }
}

class LoanDraft {
  const LoanDraft({
    required this.clientId,
    required this.principalCents,
    required this.rateBps,
    required this.rateMode,
    required this.contractMode,
    required this.frequency,
    required this.intervalDays,
    required this.count,
    required this.contractDate,
    required this.skipSaturday,
    required this.skipSunday,
    required this.skipHoliday,
    required this.lateMode,
    required this.latePercentBps,
    required this.lateDailyCents,
    required this.lateFixedCents,
    required this.notes,
    this.skipWeekdays = 0,
    this.fixedInstallment = false,
    this.openInterest = false,
    this.firstDue,
    this.chargeFrequency,
    this.dueOverrides = const {},
    this.amountOverrides = const {},
    this.pixKey = '',
  });

  final String pixKey;
  final int clientId;
  final int principalCents;
  final int rateBps;
  final RateMode rateMode;
  final ContractMode contractMode;
  final Frequency frequency;
  final int intervalDays;
  final int count;
  final DateTime contractDate;
  final bool skipSaturday;
  final bool skipSunday;
  final bool skipHoliday;
  final String lateMode;
  final int latePercentBps;
  final int lateDailyCents;
  final int lateFixedCents;
  final String notes;
  final int skipWeekdays;
  final bool fixedInstallment;
  final bool openInterest;
  final DateTime? firstDue;
  final Frequency? chargeFrequency;
  final Map<int, DateTime> dueOverrides;
  final Map<int, int> amountOverrides;
}

class PlannedInstallment {
  const PlannedInstallment({
    required this.number,
    required this.due,
    required this.principalCents,
    required this.interestCents,
  });

  final int number;
  final DateTime due;
  final int principalCents;
  final int interestCents;

  int get totalCents => principalCents + interestCents;
}

List<PlannedInstallment> buildSchedule(LoanDraft draft) {
  if (draft.openInterest) {
    return _withOverrides(_openInterest(draft), draft);
  }
  if (draft.count < 1) {
    throw ArgumentError('O contrato precisa de ao menos uma parcela.');
  }
  if (draft.principalCents < 0) {
    throw ArgumentError('Valor inválido.');
  }

  final slices = _slices(draft);
  return _withOverrides([
    for (var i = 0; i < slices.length; i++)
      PlannedInstallment(
        number: i + 1,
        due: _dueDate(draft, i + 1),
        principalCents: slices[i].principal,
        interestCents: slices[i].interest,
      ),
  ], draft);
}

int lateFeeCents({
  required int baseCents,
  required int days,
  required String mode,
  required int percentBps,
  required int dailyCents,
  required int fixedCents,
}) {
  if (days <= 0 || mode == 'sem_mora' || baseCents <= 0) return 0;
  final percent = (baseCents * (percentBps / 10000) * days).round();
  return switch (mode) {
    'percentual_dia' => percent,
    'valor_fixo' => dailyCents * days,
    'taxa_unica_percentual' => fixedCents + percent,
    _ => 0,
  };
}

class _Slice {
  const _Slice(this.principal, this.interest);
  final int principal;
  final int interest;
}

List<_Slice> _slices(LoanDraft draft) {
  final count = draft.count;
  final principal = draft.principalCents;
  final rate = draft.rateBps / 10000.0;

  if (draft.contractMode == ContractMode.apenasJuros) {
    final totalInterest = draft.rateMode == RateMode.porParcela
        ? (principal * rate).round() * count
        : (principal * rate).round();
    final base = totalInterest ~/ count;
    final remainder = totalInterest - base * count;
    return [
      for (var i = 1; i <= count; i++)
        _Slice(
          i == count ? principal : 0,
          base + (i == count ? remainder : 0),
        ),
    ];
  }

  if (draft.rateMode == RateMode.total || rate == 0) {
    final totalInterest = (principal * rate).round();
    final total = principal + totalInterest;
    final payBase = total ~/ count;
    final payRemainder = total - payBase * count;
    final principalBase = principal ~/ count;
    final principalRemainder = principal - principalBase * count;
    return [
      for (var i = 1; i <= count; i++)
        _Slice(
          principalBase + (i == count ? principalRemainder : 0),
          (payBase + (i == count ? payRemainder : 0)) -
              (principalBase + (i == count ? principalRemainder : 0)),
        ),
    ];
  }

  final factor = math.pow(1 + rate, count).toDouble();
  final payment = (principal * rate * factor / (factor - 1)).round();
  final slices = <_Slice>[];
  var balance = principal;
  for (var i = 1; i <= count; i++) {
    final interest = (balance * rate).round();
    var principalPart = payment - interest;
    if (i == count || principalPart > balance) principalPart = balance;
    if (principalPart < 0) principalPart = 0;
    balance -= principalPart;
    slices.add(_Slice(principalPart, interest));
  }
  if (balance != 0 && slices.isNotEmpty) {
    final last = slices.removeLast();
    slices.add(_Slice(last.principal + balance, last.interest));
  }
  return slices;
}

Frequency spacingOf(LoanDraft draft) {
  if (draft.chargeFrequency != null) return draft.chargeFrequency!;
  if (draft.frequency == Frequency.personalizado) return Frequency.mensal;
  return draft.frequency;
}

DateTime nextChargeDate({
  required DateTime from,
  required Frequency frequency,
  required int intervalDays,
  required bool skipSaturday,
  required bool skipSunday,
  required bool skipHoliday,
  required int skipWeekdays,
}) {
  return _dueDate(
    LoanDraft(
      clientId: 0,
      principalCents: 0,
      rateBps: 0,
      rateMode: RateMode.porParcela,
      contractMode: ContractMode.apenasJuros,
      frequency: frequency,
      intervalDays: intervalDays,
      count: 1,
      contractDate: from,
      skipSaturday: skipSaturday,
      skipSunday: skipSunday,
      skipHoliday: skipHoliday,
      lateMode: 'sem_mora',
      latePercentBps: 0,
      lateDailyCents: 0,
      lateFixedCents: 0,
      notes: '',
      skipWeekdays: skipWeekdays,
    ),
    1,
  );
}

List<PlannedInstallment> _openInterest(LoanDraft draft) {
  final due = draft.firstDue == null ? _dueDate(draft, 1) : _shift(draft.firstDue!, draft);
  final interest = (draft.principalCents * (draft.rateBps / 10000)).round();
  return [
    PlannedInstallment(number: 1, due: due, principalCents: 0, interestCents: interest),
    PlannedInstallment(number: 2, due: due, principalCents: draft.principalCents, interestCents: 0),
  ];
}

List<PlannedInstallment> _withOverrides(List<PlannedInstallment> plan, LoanDraft draft) {
  if (draft.dueOverrides.isEmpty && draft.amountOverrides.isEmpty) return plan;
  return [for (final item in plan) _override(item, draft)];
}

PlannedInstallment _override(PlannedInstallment item, LoanDraft draft) {
  var principal = item.principalCents;
  var interest = item.interestCents;
  final amount = draft.amountOverrides[item.number];
  if (amount != null && amount >= 0) {
    if (amount >= principal) {
      interest = amount - principal;
    } else {
      principal = amount;
      interest = 0;
    }
  }
  final due = draft.dueOverrides[item.number];
  return PlannedInstallment(
    number: item.number,
    due: due == null ? item.due : _shift(due, draft),
    principalCents: principal,
    interestCents: interest,
  );
}

DateTime _dueDate(LoanDraft draft, int index) {
  final spacing = spacingOf(draft);
  final origin = dateOnly(draft.firstDue ?? draft.contractDate);
  final steps = draft.firstDue == null ? index : index - 1;
  final DateTime raw;
  if (spacing == Frequency.mensal) {
    raw = addMonths(origin, steps);
  } else {
    final step = switch (spacing) {
      Frequency.diario => 1,
      Frequency.semanal => 7,
      Frequency.dezDias => 10,
      Frequency.quinzenal => 15,
      Frequency.nDias => draft.intervalDays < 1 ? 1 : draft.intervalDays,
      Frequency.mensal || Frequency.personalizado => 30,
    };
    raw = origin.add(Duration(days: step * steps));
  }
  return _shift(raw, draft);
}

DateTime _shift(DateTime date, LoanDraft draft) {
  var current = dateOnly(date);
  for (var i = 0; i < 21; i++) {
    final blockedWeekend =
        (draft.skipSaturday && current.weekday == DateTime.saturday) ||
        (draft.skipSunday && current.weekday == DateTime.sunday);
    final blockedWeekday = switch (current.weekday) {
      DateTime.monday => (draft.skipWeekdays & 1) != 0,
      DateTime.tuesday => (draft.skipWeekdays & 2) != 0,
      DateTime.wednesday => (draft.skipWeekdays & 4) != 0,
      DateTime.thursday => (draft.skipWeekdays & 8) != 0,
      DateTime.friday => (draft.skipWeekdays & 16) != 0,
      _ => false,
    };
    final blockedHoliday = draft.skipHoliday && isBrazilianHoliday(current);
    if (!blockedWeekend && !blockedWeekday && !blockedHoliday) return current;
    current = current.add(const Duration(days: 1));
  }
  return current;
}
