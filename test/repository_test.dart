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
}
