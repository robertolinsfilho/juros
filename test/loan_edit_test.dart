import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/data/repository.dart';
import 'package:juros/src/domain/schedule.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/loan_edit.dart';
import 'package:sqlite3/sqlite3.dart';

LoanDraft sample(int clientId, {int count = 3, ContractMode mode = ContractMode.amortizacao}) {
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
    notes: 'antes',
    openInterest: mode == ContractMode.apenasJuros,
    firstDue: mode == ContractMode.apenasJuros ? DateTime(2026, 11, 27) : null,
  );
}

void main() {
  late Repo repo;
  late int clientId;

  setUp(() {
    repo = Repo(sqlite3.openInMemory(), ':memory:');
    clientId = repo.saveClient(name: 'Maria', document: '', phone: '86999999999', zip: '', address: '', workAddress: '');
  });
  tearDown(() => repo.close());

  test('sem pagamentos, editar recalcula valor, taxa e parcelas', () {
    final id = repo.createLoan(sample(clientId));
    expect(repo.installmentsOf(id).length, 3);
    final draft = repo.draftOf(id)!;
    final changed = LoanDraft(
      clientId: draft.clientId,
      principalCents: 200000,
      rateBps: 500,
      rateMode: draft.rateMode,
      contractMode: draft.contractMode,
      frequency: draft.frequency,
      intervalDays: draft.intervalDays,
      count: 2,
      contractDate: draft.contractDate,
      skipSaturday: draft.skipSaturday,
      skipSunday: draft.skipSunday,
      skipHoliday: draft.skipHoliday,
      lateMode: 'percentual_dia',
      latePercentBps: 100,
      lateDailyCents: 0,
      lateFixedCents: 0,
      notes: 'depois',
    );
    repo.updateLoan(id, changed, rebuild: true);
    final loan = repo.loanById(id)!;
    expect(loan.principalCents, 200000);
    expect(loan.rateBps, 500);
    expect(loan.count, 2);
    expect(loan.notes, 'depois');
    expect(loan.lateMode, 'percentual_dia');
    expect(loan.lateExplain, isFalse);
    expect(repo.installmentsOf(id).length, 2);
  });

  test('com parcela paga, só mora e observações mudam e recalcular é recusado', () {
    final id = repo.createLoan(sample(clientId));
    repo.payInstallment(repo.installmentsOf(id).first.id, DateTime(2026, 11, 27));
    expect(repo.loanHasPayments(id), true);
    final draft = repo.draftOf(id)!;
    final changed = LoanDraft(
      clientId: draft.clientId,
      principalCents: 999,
      rateBps: 1,
      rateMode: draft.rateMode,
      contractMode: draft.contractMode,
      frequency: draft.frequency,
      intervalDays: draft.intervalDays,
      count: 9,
      contractDate: draft.contractDate,
      skipSaturday: true,
      skipSunday: false,
      skipHoliday: false,
      lateMode: 'valor_fixo',
      latePercentBps: 0,
      lateDailyCents: 500,
      lateFixedCents: 0,
      notes: 'nova obs',
    );
    expect(() => repo.updateLoan(id, changed, rebuild: true), throwsStateError);
    repo.updateLoan(id, changed, rebuild: false);
    final loan = repo.loanById(id)!;
    expect(loan.principalCents, 100000);
    expect(loan.count, 3);
    expect(loan.notes, 'nova obs');
    expect(loan.lateMode, 'valor_fixo');
    expect(repo.installmentsOf(id).length, 3);
  });

  test('grava a explicação da mora e devolve no rascunho', () {
    final id = repo.createLoan(
      LoanDraft(
        clientId: clientId,
        principalCents: 100000,
        rateBps: 1000,
        rateMode: RateMode.porParcela,
        contractMode: ContractMode.amortizacao,
        frequency: Frequency.mensal,
        intervalDays: 0,
        count: 1,
        contractDate: DateTime(2026, 10, 27),
        skipSaturday: false,
        skipSunday: false,
        skipHoliday: false,
        lateMode: 'percentual_dia',
        latePercentBps: 100,
        lateDailyCents: 0,
        lateFixedCents: 0,
        lateExplain: true,
        lateExplainText: '*Se atrasar:* cada parcela soma 1% ao dia.',
        notes: '',
      ),
    );
    final loan = repo.loanById(id)!;
    expect(loan.lateExplain, isTrue);
    expect(loan.lateExplainText, contains('1% ao dia'));
    final draft = repo.draftOf(id)!;
    expect(draft.lateExplain, isTrue);
    expect(draft.lateExplainText, contains('1% ao dia'));
  });

  testWidgets('tela de edição abre travada em juros + capital', (tester) async {
    final id = repo.createLoan(sample(clientId, mode: ContractMode.apenasJuros));
    final loan = repo.loanById(id)!;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => TextButton(onPressed: () => showLoanEdit(context, repo, loan), child: const Text('abrir')),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Editar empréstimo'), findsOneWidget);
    expect(find.textContaining('não podem ser alterados aqui'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsOneWidget);
  });
}
