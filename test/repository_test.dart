import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/data/repository.dart';
import 'package:juros/src/domain/schedule.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('receber a última parcela quita o contrato', () {
    final repo = Repo(sqlite3.openInMemory(), ':memory:');
    addTearDown(repo.close);
    final clientId = repo.saveClient(name: 'Maria', document: '', phone: '86999999999', zip: '', address: '', workAddress: '');
    final loanId = repo.createLoan(
      LoanDraft(
        clientId: clientId,
        principalCents: 10000,
        rateBps: 0,
        rateMode: RateMode.total,
        contractMode: ContractMode.amortizacao,
        frequency: Frequency.mensal,
        intervalDays: 0,
        count: 1,
        contractDate: DateTime(2026, 10, 1),
        skipSaturday: false,
        skipSunday: false,
        skipHoliday: false,
        lateMode: 'sem_mora',
        latePercentBps: 0,
        lateDailyCents: 0,
        lateFixedCents: 0,
        notes: '',
      ),
    );
    final installment = repo.installmentsOf(loanId).single;
    expect(installment.dueDate, '2026-11-01');
    repo.payInstallment(installment.id, DateTime(2026, 11, 1));
    final paid = repo.installmentsOf(loanId).single;
    expect(paid.paidAt, '2026-11-01');
    final loan = repo.loanById(loanId, DateTime(2026, 11, 1))!;
    expect(loan.displayStatus, 'Quitado');
    final dash = repo.dashboard(DateTime(2026, 11, 2));
    expect(dash.expectedCents, 0);
    expect(dash.receivedMonthCents, 10000);
  });

  test('o aviso lista a cobrança que está chegando e não repete depois do envio', () {
    final repo = Repo(sqlite3.openInMemory(), ':memory:');
    addTearDown(repo.close);
    final clientId = repo.saveClient(name: 'Maria', document: '', phone: '86999999999', zip: '', address: '', workAddress: '');
    final loanId = repo.createLoan(
      LoanDraft(
        clientId: clientId,
        principalCents: 10000,
        rateBps: 0,
        rateMode: RateMode.total,
        contractMode: ContractMode.amortizacao,
        frequency: Frequency.mensal,
        intervalDays: 0,
        count: 1,
        contractDate: DateTime(2026, 10, 1),
        skipSaturday: false,
        skipSunday: false,
        skipHoliday: false,
        lateMode: 'sem_mora',
        latePercentBps: 0,
        lateDailyCents: 0,
        lateFixedCents: 0,
        notes: '',
      ),
    );
    final installment = repo.installmentsOf(loanId).single;
    expect(installment.dueDate, '2026-11-01');
    expect(repo.reminderDays, 1);
    expect(repo.dueReminders(DateTime(2026, 10, 30)), isEmpty);
    repo.setReminderDays(2);
    final pending = repo.dueReminders(DateTime(2026, 10, 30));
    expect(pending.map((item) => item.id), [installment.id]);
    repo.markReminderSent(pending.single, DateTime(2026, 10, 30));
    expect(repo.dueReminders(DateTime(2026, 10, 31)), isEmpty);
    expect(repo.dueReminders(DateTime(2026, 11, 2)), isEmpty);
  });

  test('o calendário mostra o valor em aberto do dia escolhido, com a mora', () {
    final repo = Repo(sqlite3.openInMemory(), ':memory:');
    addTearDown(repo.close);
    final clientId = repo.saveClient(name: 'Maria', document: '', phone: '86999999999', zip: '', address: '', workAddress: '');
    LoanDraft draft(DateTime contract, String lateMode, int percent) {
      return LoanDraft(
        clientId: clientId,
        principalCents: 10000,
        rateBps: 0,
        rateMode: RateMode.total,
        contractMode: ContractMode.amortizacao,
        frequency: Frequency.mensal,
        intervalDays: 0,
        count: 1,
        contractDate: contract,
        skipSaturday: false,
        skipSunday: false,
        skipHoliday: false,
        lateMode: lateMode,
        latePercentBps: percent,
        lateDailyCents: 0,
        lateFixedCents: 0,
        notes: '',
      );
    }

    final paidId = repo.createLoan(draft(DateTime(2026, 10, 1), 'sem_mora', 0));
    final paid = repo.installmentsOf(paidId).single;
    expect(paid.dueDate, '2026-11-01');
    repo.payInstallment(paid.id, DateTime(2026, 11, 1));

    final openId = repo.createLoan(draft(DateTime(2026, 10, 3), 'percentual_dia', 100));
    final open = repo.installmentsOf(openId).single;
    expect(open.dueDate, '2026-11-03');

    final today = DateTime(2026, 11, 4);
    expect(repo.monthPulse(DateTime(2026, 11, 1)).receivedToday, 10000);
    expect(repo.monthPulse(DateTime(2026, 11, 3)).receivedToday, 0);
    final amounts = repo.dueAmountsInMonth(DateTime(2026, 11, 1), today);
    expect(amounts[1], isNull);
    expect(amounts[3], 10100);
    expect(repo.dueOn(DateTime(2026, 11, 3)).single.dueCents(today), amounts[3]);

    final alerts = repo.paymentAlerts(today);
    expect(alerts.unpaid.map((item) => item.id), [open.id]);
    expect(alerts.upcoming, isEmpty);

    final soonId = repo.createLoan(draft(DateTime(2026, 10, 5), 'sem_mora', 0));
    final soon = repo.installmentsOf(soonId).single;
    expect(soon.dueDate, '2026-11-05');
    final later = repo.paymentAlerts(today);
    expect(later.upcoming.map((item) => item.id), [soon.id]);
    expect(repo.dueReminders(DateTime(2026, 11, 6)), isEmpty);
  });

  test('o lembrete marca um dia sem mudar o vencimento e entra no calendário', () {
    final repo = Repo(sqlite3.openInMemory(), ':memory:');
    addTearDown(repo.close);
    final clientId = repo.saveClient(name: 'Almir', document: '', phone: '86999999999', zip: '', address: '', workAddress: '');
    final loanId = repo.createLoan(
      LoanDraft(
        clientId: clientId,
        principalCents: 30000,
        rateBps: 0,
        rateMode: RateMode.total,
        contractMode: ContractMode.amortizacao,
        frequency: Frequency.mensal,
        intervalDays: 0,
        count: 1,
        contractDate: DateTime(2026, 10, 20),
        skipSaturday: false,
        skipSunday: false,
        skipHoliday: false,
        lateMode: 'sem_mora',
        latePercentBps: 0,
        lateDailyCents: 0,
        lateFixedCents: 0,
        notes: '',
      ),
    );
    final item = repo.installmentsOf(loanId).single;
    expect(item.dueDate, '2026-11-20');
    expect(item.promiseDate, isNull);

    repo.setPromiseDate(item.id, '2026-11-08');
    final marked = repo.installmentsOf(loanId).single;
    expect(marked.dueDate, '2026-11-20');
    expect(marked.promiseDate, '2026-11-08');
    expect(repo.promiseDaysInMonth(DateTime(2026, 11, 1)), {8});
    expect(repo.dueOn(DateTime(2026, 11, 8)).map((row) => row.id), [item.id]);
    expect(repo.dueOn(DateTime(2026, 11, 20)).map((row) => row.id), [item.id]);
    final amounts = repo.dueAmountsInMonth(DateTime(2026, 11, 1), DateTime(2026, 11, 4));
    expect(amounts[8], isNull);
    expect(amounts[20], 30000);

    expect(repo.paymentAlerts(DateTime(2026, 11, 7)).upcoming, isEmpty);
    expect(repo.paymentAlerts(DateTime(2026, 11, 8)).upcoming.map((row) => row.id), [item.id]);
    expect(repo.paymentAlerts(DateTime(2026, 11, 19)).upcoming.map((row) => row.id), [item.id]);

    final snap = repo.accountSnapshot();
    expect((snap['installments'] as List).single['promise_date'], '2026-11-08');
    repo.setPromiseDate(item.id, null);
    expect(repo.installmentsOf(loanId).single.promiseDate, isNull);
    expect(repo.dueOn(DateTime(2026, 11, 8)), isEmpty);
    repo.replaceAccount(snap);
    expect(repo.installmentsOf(loanId).single.promiseDate, '2026-11-08');

    repo.payInstallment(item.id, DateTime(2026, 11, 8));
    expect(repo.promiseDaysInMonth(DateTime(2026, 11, 1)), isEmpty);
    expect(repo.dueOn(DateTime(2026, 11, 8)), isEmpty);
  });

  test('a cópia da conta volta o cliente e deixa o token nesta tela', () {
    final repo = Repo(sqlite3.openInMemory(), ':memory:');
    addTearDown(repo.close);
    repo.setSetting('session_token', 'segredo');
    repo.setSetting('creditor_name', 'Casa');
    repo.saveClient(
      name: 'Maria',
      document: '',
      phone: '86999999999',
      zip: '',
      address: '',
      workAddress: '',
    );
    final snap = repo.accountSnapshot();
    expect((snap['settings'] as Map).containsKey('session_token'), isFalse);
    repo.saveClient(
      name: 'Outro',
      document: '',
      phone: '86988888888',
      zip: '',
      address: '',
      workAddress: '',
    );
    repo.replaceAccount(snap);
    expect(repo.setting('session_token'), 'segredo');
    expect(repo.setting('creditor_name'), 'Casa');
    expect(repo.listClients().map((item) => item.name), ['Maria']);
  });
}
