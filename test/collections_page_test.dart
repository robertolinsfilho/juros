import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/data/repository.dart';
import 'package:juros/src/domain/schedule.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/collections_page.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  testWidgets('os botões da cobrança ficam na mesma linha', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
        contractDate: DateTime(2020, 10, 1),
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
    repo.setPromiseDate(item.id, '2026-11-08');

    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: Scaffold(body: CollectionsPage(repo: repo))),
    );
    await tester.pumpAndSettle();

    final cobrar = tester.getRect(find.text('Cobrar').first);
    final receber = tester.getRect(find.text('Receber').first);
    final eye = tester.getRect(find.byTooltip('Ver detalhes').first);
    expect((receber.center.dy - cobrar.center.dy).abs(), lessThan(2));
    expect((eye.center.dy - receber.center.dy).abs(), lessThan(4));
    expect(cobrar.height, lessThan(40));
    expect(receber.height, lessThan(40));
    expect(find.text('08/11'), findsWidgets);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: Scaffold(body: CollectionsPage(repo: repo))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
