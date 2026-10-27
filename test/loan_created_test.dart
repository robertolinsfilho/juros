import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/data/repository.dart';
import 'package:juros/src/domain/schedule.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/loan_created.dart';
import 'package:sqlite3/sqlite3.dart';

LoanDraft draft(int clientId, ContractMode mode, {int count = 1}) {
  return LoanDraft(
    clientId: clientId,
    principalCents: 100000,
    rateBps: 1000,
    rateMode: RateMode.porParcela,
    contractMode: mode,
    frequency: Frequency.mensal,
    intervalDays: 0,
    count: count,
    contractDate: DateTime(2026, 10, 27),
    skipSaturday: false,
    skipSunday: false,
    skipHoliday: false,
    lateMode: 'sem_mora',
    latePercentBps: 0,
    lateDailyCents: 0,
    lateFixedCents: 0,
    notes: '',
    openInterest: mode == ContractMode.apenasJuros,
    firstDue: mode == ContractMode.apenasJuros ? DateTime(2026, 11, 27) : null,
  );
}

void main() {
  late Repo repo;
  late int clientId;

  setUp(() {
    repo = Repo(sqlite3.openInMemory(), ':memory:');
    clientId = repo.saveClient(name: 'Roberto Lins', document: '', phone: '86999999999', zip: '', address: '', workAddress: '');
  });
  tearDown(() => repo.close());

  testWidgets('juros + capital mostra a tela de empréstimo criado', (tester) async {
    final loanId = repo.createLoan(draft(clientId, ContractMode.apenasJuros));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLoanCreated(context, repo, loanId),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Empréstimo Criado!'), findsOneWidget);
    expect(find.text('Contrato registrado com sucesso'), findsOneWidget);
    expect(find.text('Roberto Lins'), findsOneWidget);
    expect(find.text('JUROS MENSAL'), findsOneWidget);
    expect(find.text('CAPITAL A DEVOLVER'), findsOneWidget);
    expect(find.text('Juros 1'), findsOneWidget);
    expect(find.text('27/11/2026'), findsOneWidget);
    expect(find.text('Enviar via WhatsApp'), findsOneWidget);
    expect(find.text('Copiar Resumo'), findsOneWidget);

    final summary = LoanSummary.load(repo, loanId);
    final text = summary.message;
    expect(text, contains('Roberto Lins'));
    expect(text, contains('27/11/2026'));
    expect(text, isNot(contains('{{')));
  });

  test('parcelado lista parcelas e total', () {
    final loanId = repo.createLoan(draft(clientId, ContractMode.amortizacao, count: 3));
    final summary = LoanSummary.load(repo, loanId);
    expect(summary.rows.length, 3);
    expect(summary.secondLabel, 'Parcelas');
    expect(summary.thirdLabel, 'Total a pagar');
  });
}
