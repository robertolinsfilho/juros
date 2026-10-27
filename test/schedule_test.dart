import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/domain/holidays.dart';
import 'package:juros/src/domain/schedule.dart';
import 'package:juros/src/format.dart';

LoanDraft draft({
  int principal = 100000,
  int rateBps = 1000,
  RateMode rateMode = RateMode.porParcela,
  ContractMode contractMode = ContractMode.amortizacao,
  Frequency frequency = Frequency.mensal,
  int count = 3,
  DateTime? date,
  bool saturday = false,
  bool sunday = false,
  bool holiday = false,
  int interval = 1,
}) {
  return LoanDraft(
    clientId: 1,
    principalCents: principal,
    rateBps: rateBps,
    rateMode: rateMode,
    contractMode: contractMode,
    frequency: frequency,
    intervalDays: interval,
    count: count,
    contractDate: date ?? DateTime(2026, 1, 31),
    skipSaturday: saturday,
    skipSunday: sunday,
    skipHoliday: holiday,
    lateMode: 'sem_mora',
    latePercentBps: 0,
    lateDailyCents: 0,
    lateFixedCents: 0,
    notes: '',
  );
}

void main() {
  test('juros total parcelado divide capital e juros', () {
    final plan = buildSchedule(draft(rateMode: RateMode.total, count: 2));
    expect(plan.fold<int>(0, (sum, item) => sum + item.principalCents), 100000);
    expect(plan.fold<int>(0, (sum, item) => sum + item.interestCents), 10000);
    expect(plan.first.totalCents, 55000);
    expect(plan.last.totalCents, 55000);
  });

  test('apenas juros cobra o capital na última parcela', () {
    final plan = buildSchedule(
      draft(contractMode: ContractMode.apenasJuros, count: 3),
    );
    expect(plan[0].principalCents, 0);
    expect(plan[0].interestCents, 10000);
    expect(plan[2].principalCents, 100000);
    expect(plan.fold<int>(0, (sum, item) => sum + item.totalCents), 130000);
  });

  test('taxa zero divide o capital sem juros', () {
    final plan = buildSchedule(draft(rateBps: 0, count: 4, principal: 1000));
    expect(plan.every((item) => item.interestCents == 0), isTrue);
    expect(plan.fold<int>(0, (sum, item) => sum + item.principalCents), 1000);
  });

  test('price devolve o capital inteiro', () {
    final plan = buildSchedule(draft(rateBps: 100, count: 12, principal: 100000));
    expect(plan.fold<int>(0, (sum, item) => sum + item.principalCents), 100000);
    expect(plan.every((item) => item.interestCents >= 0), isTrue);
  });

  test('mensal a partir de 31 cai no fim do mês curto', () {
    final plan = buildSchedule(draft(count: 2));
    expect(isoDate(plan[0].due), '2026-02-28');
    expect(isoDate(plan[1].due), '2026-03-31');
  });

  test('pula sábado, domingo e feriado', () {
    final plan = buildSchedule(
      draft(
        frequency: Frequency.diario,
        count: 1,
        date: DateTime(2026, 10, 30),
        saturday: true,
        sunday: true,
        holiday: true,
      ),
    );
    expect(isoDate(plan.single.due), '2026-11-03');
  });

  test('páscoa de 2026', () {
    expect(isoDate(easterSunday(2026)), '2026-04-05');
  });

  test('mora percentual e taxa única', () {
    expect(
      lateFeeCents(baseCents: 10000, days: 2, mode: 'percentual_dia', percentBps: 100, dailyCents: 0, fixedCents: 0),
      200,
    );
    expect(
      lateFeeCents(baseCents: 10000, days: 2, mode: 'taxa_unica_percentual', percentBps: 100, dailyCents: 0, fixedCents: 500),
      700,
    );
    expect(
      lateFeeCents(baseCents: 10000, days: 0, mode: 'valor_fixo', percentBps: 0, dailyCents: 100, fixedCents: 0),
      0,
    );
  });
}
