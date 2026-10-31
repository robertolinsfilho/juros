import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/data/repository.dart';
import 'package:juros/src/domain/schedule.dart';
import 'package:juros/src/messages/builders.dart';
import 'package:juros/src/messages/templates.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/settings_page.dart';
import 'package:sqlite3/sqlite3.dart';

LoanDraft draft(int clientId, ContractMode mode, {int count = 1, String pixKey = ''}) {
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
    pixKey: pixKey,
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

  test('renderTemplate troca variáveis e limpa linhas vazias', () {
    final text = renderTemplate('Oi {{nome}}\n\n\n\n{{vazio}}\nFim', {'nome': 'Ana'});
    expect(text, 'Oi Ana\n\nFim');
  });

  test('todos os modelos padrão só usam variáveis declaradas', () {
    for (final kind in templateKinds) {
      final used = RegExp(r'\{\{(\w+)\}\}').allMatches(kind.body).map((m) => m[1]!).toSet();
      expect(kind.variables.toSet().containsAll(used), isTrue, reason: kind.id);
      final rendered = renderTemplate(kind.body, sampleVariables(composeSignature(creditor: 'Eu')));
      expect(rendered, isNot(contains('{{')), reason: kind.id);
    }
  });

  test('assinatura respeita os botões Mostrar e a chave do contrato', () {
    final config = MessageConfig(repo);
    config.saveSignature(
      creditor: 'Roberto',
      showCreditor: true,
      company: 'Acerta',
      showCompany: false,
      pix: 'chave-a',
      showPix: true,
      fraction: false,
    );
    expect(config.signature(), allOf(contains('Roberto'), contains('PIX: chave-a'), isNot(contains('Acerta'))));
    expect(config.signature(pixOverride: 'chave-b'), contains('PIX: chave-b'));
    config.saveSignature(
      creditor: 'Roberto',
      showCreditor: false,
      company: 'Acerta',
      showCompany: true,
      pix: 'chave-a',
      showPix: false,
      fraction: false,
    );
    final text = config.signature();
    expect(text, contains('Acerta'));
    expect(text, isNot(contains('Roberto')));
    expect(text, isNot(contains('PIX')));
  });

  test('template personalizado ativo substitui o padrão e pode ser desativado', () {
    final config = MessageConfig(repo);
    config.saveCustoms([const CustomTemplate(id: '1', kind: 'atrasado', name: 'Meu', body: 'Pague {{cliente_nome}}')]);
    config.setActiveCustom('atrasado', '1');
    expect(config.bodyFor('atrasado'), 'Pague {{cliente_nome}}');
    config.setActiveCustom('atrasado', '');
    expect(config.bodyFor('atrasado'), kindById('atrasado').body);
    config.saveOverride('atrasado', 'editado');
    expect(config.bodyFor('atrasado'), 'editado');
    config.resetOverride('atrasado');
    expect(config.hasOverride('atrasado'), isFalse);
  });

  test('cobrança inclui a explicação da mora quando o contrato pede', () {
    final loanId = repo.createLoan(
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
        lateExplainText:
            '*Se atrasar:* a cada dia de atraso, cada parcela em aberto soma 1% ao dia sobre o valor dela (mora).',
        notes: '',
      ),
    );
    final item = repo.installmentsOf(loanId).first;
    final builder = MessageBuilder(repo);
    final charge = builder.charge(item, today: DateTime(2026, 11, 20));
    final situation = builder.status(loanId, today: DateTime(2026, 11, 1));
    expect(charge, contains('soma 1% ao dia sobre o valor dela'));
    expect(charge.trim().endsWith('(mora).'), isTrue);
    expect(situation, contains('soma 1% ao dia sobre o valor dela'));
    expect(situation.trim().endsWith('(mora).'), isTrue);
    final without = builder.charge(
      repo.installmentsOf(repo.createLoan(draft(clientId, ContractMode.amortizacao))).first,
      today: DateTime(2026, 11, 20),
    );
    expect(without, isNot(contains('Se atrasar')));
    expect(builder.status(repo.createLoan(draft(clientId, ContractMode.amortizacao))), isNot(contains('Se atrasar')));
  });

  test('cobrança escolhe o modelo pela situação', () {
    final loanId = repo.createLoan(draft(clientId, ContractMode.amortizacao, count: 2));
    final item = repo.installmentsOf(loanId).first;
    final builder = MessageBuilder(repo);
    final antes = builder.charge(item, today: DateTime(2026, 11, 20));
    final hoje = builder.charge(item, today: DateTime(2026, 11, 27));
    final atraso = builder.charge(item, today: DateTime(2026, 12, 2));
    expect({antes, hoje, atraso}.length, 3);
    for (final text in [antes, hoje, atraso]) {
      expect(text, contains('Roberto Lins'));
      expect(text, isNot(contains('{{')));
    }
    expect(atraso, contains('5'));
  });

  test('template personalizado muda a cobrança', () {
    final loanId = repo.createLoan(draft(clientId, ContractMode.amortizacao, count: 2));
    final item = repo.installmentsOf(loanId).first;
    final config = MessageConfig(repo);
    config.saveOverride('pre_vencimento', 'Parcela {{parcela_numero}}/{{total_parcelas}} de {{cliente_nome}}: {{parcela_valor}}');
    final text = MessageBuilder(repo).charge(item, today: DateTime(2026, 11, 20));
    expect(text, 'Parcela 1/2 de Roberto Lins: R\$ 576,19');
  });

  test('chave PIX do empréstimo aparece na assinatura', () {
    MessageConfig(repo).saveSignature(
      creditor: 'Eu',
      showCreditor: true,
      company: '',
      showCompany: false,
      pix: 'padrao',
      showPix: true,
      fraction: false,
    );
    final loanId = repo.createLoan(draft(clientId, ContractMode.amortizacao, count: 2, pixKey: 'outra'));
    final text = MessageBuilder(repo).registered(loanId);
    expect(text, contains('PIX: outra'));
    expect(text, isNot(contains('PIX: padrao')));
  });

  test('lista de parcelas usa emoji ou fração', () {
    final loanId = repo.createLoan(draft(clientId, ContractMode.amortizacao, count: 2));
    final config = MessageConfig(repo);
    expect(MessageBuilder(repo).registered(loanId), contains('1️⃣'));
    config.saveSignature(
      creditor: '',
      showCreditor: true,
      company: '',
      showCompany: false,
      pix: '',
      showPix: true,
      fraction: true,
    );
    final text = MessageBuilder(repo).registered(loanId);
    expect(text, contains('1/2'));
    expect(text, isNot(contains('1️⃣')));
  });

  test('juros + capital usa o modelo de juros', () {
    final loanId = repo.createLoan(draft(clientId, ContractMode.apenasJuros));
    final text = MessageBuilder(repo).registered(loanId);
    expect(text, contains('27/11/2026'));
    expect(text, isNot(contains('{{')));
  });

  test('mais de um contrato em atraso gera cobrança consolidada', () {
    final first = repo.createLoan(draft(clientId, ContractMode.amortizacao, count: 1));
    repo.createLoan(draft(clientId, ContractMode.amortizacao, count: 1));
    final item = repo.installmentsOf(first).first;
    final text = MessageBuilder(repo).charge(item, today: DateTime(2026, 12, 5));
    expect(text, contains('Contrato nº $first'));
    expect(text, contains('Contrato nº ${first + 1}'));
  });

  test('mensagem de situação e de pagamento', () {
    final loanId = repo.createLoan(draft(clientId, ContractMode.amortizacao, count: 2));
    final item = repo.installmentsOf(loanId).first;
    final builder = MessageBuilder(repo);
    expect(builder.status(loanId, today: DateTime(2026, 11, 1)), isNot(contains('{{')));
    repo.payInstallment(item.id, DateTime(2026, 11, 27));
    final text = builder.payment(item, today: DateTime(2026, 11, 27));
    expect(text, contains('Roberto Lins'));
    expect(text, isNot(contains('{{')));
  });

  testWidgets('aba Mensagens abre, edita assinatura e cria template', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: SettingsPage(repo: repo, onChanged: () {})),
      ),
    );
    expect(find.text('Assinatura das mensagens'), findsOneWidget);
    expect(find.text('Templates WhatsApp'), findsOneWidget);
    expect(find.text('Empréstimo Registrado'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Seu nome'), 'Roberto Teste');
    await tester.pump();
    await tester.tap(find.text('Salvar assinatura'));
    await tester.pump();
    expect(repo.setting('creditor_name'), 'Roberto Teste');

    await tester.tap(find.text('Novo template'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome do template'), 'Meu modelo');
    await tester.enterText(find.widgetWithText(TextField, 'Mensagem'), 'Oi {{cliente_nome}}');
    await tester.pump();
    expect(find.textContaining('Oi João Silva'), findsWidgets);
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();
    final config = MessageConfig(repo);
    expect(config.customs.single.name, 'Meu modelo');
    expect(config.activeCustomId('registrado'), config.customs.single.id);
  });
}
