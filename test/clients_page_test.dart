import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/data/repository.dart';
import 'package:juros/src/domain/schedule.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/clients_page.dart';
import 'package:sqlite3/sqlite3.dart';

LoanDraft draft(int clientId, int principal) {
  return LoanDraft(
    clientId: clientId,
    principalCents: principal,
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
  );
}

void main() {
  testWidgets('clicar no cliente abre os empréstimos em aberto dele', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = Repo(sqlite3.openInMemory(), ':memory:');
    addTearDown(repo.close);
    final maria = repo.saveClient(name: 'Maria', document: '', phone: '86999999999', zip: '', address: '', workAddress: '');
    final joao = repo.saveClient(name: 'João', document: '', phone: '86988888888', zip: '', address: '', workAddress: '');
    repo.createLoan(draft(maria, 10000));
    repo.createLoan(draft(maria, 25000));
    final quitado = repo.createLoan(draft(maria, 77700));
    for (final item in repo.installmentsOf(quitado)) {
      repo.payInstallment(item.id);
    }
    repo.createLoan(draft(joao, 40000));

    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: Scaffold(body: ClientsPage(repo: repo))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maria'));
    await tester.pumpAndSettle();

    expect(find.text('EM ABERTO'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('R\$ 100,00'), findsWidgets);
    expect(find.text('R\$ 250,00'), findsWidgets);
    expect(find.text('R\$ 777,00'), findsNothing);
    expect(find.text('R\$ 400,00'), findsNothing);
  });
}
