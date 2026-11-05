import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juros/src/app.dart';
import 'package:juros/src/app_routes.dart';
import 'package:juros/src/auth/auth_api.dart';
import 'package:juros/src/data/repository.dart';
import 'package:juros/src/domain/schedule.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  testWidgets('o robô percorre o site, volta e recarrega cada tela', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = Repo(sqlite3.openInMemory(), ':memory:');
    addTearDown(repo.close);
    final routes = AppRoutes();
    final api = AuthApi(client: MockClient((request) => _api(request, role: 'comum')));

    await tester.pumpWidget(JurosApp(repo: repo, auth: api, routes: routes));
    await tester.pumpAndSettle();
    expect(find.text('Criar conta grátis'), findsOneWidget);
    expect(routes.uri.path, '/');

    await tester.tap(find.widgetWithText(TextButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(routes.uri.path, '/entrar');
    expect(find.text('Usuário'), findsOneWidget);
    await tester.tap(find.text('Voltar ao início'));
    await tester.pumpAndSettle();
    expect(routes.uri.path, '/');

    await tester.tap(find.text('Criar conta grátis'));
    await tester.pumpAndSettle();
    expect(routes.uri.path, '/criar');
    expect(find.text('E-mail'), findsOneWidget);
    await tester.tap(find.text('Voltar ao início'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Entrar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'operador');
    await tester.enterText(find.byType(TextField).at(1), 'segredo');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Resumo da operação'), findsOneWidget);
    expect(routes.uri.path, '/');
    expect(find.text('Usuários'), findsNothing);

    await routes.setNewRoutePath(Uri(path: '/'));
    await tester.pumpAndSettle();
    _seed(repo);

    const screens = <(String, String, String)>[
      ('Cobranças', '/cobrancas', 'Quem não pagou'),
      ('Clientes', '/clientes', 'Almir'),
      ('Consultas', '/consultas', 'Marketplace de Consultas'),
      ('Empréstimos', '/emprestimos', 'Almir'),
      ('Caixa', '/caixa', 'Ativar caixa'),
      ('Relatórios', '/relatorios', 'Relatórios'),
      ('Lixeira', '/lixeira', 'Lixeira vazia'),
      ('Configurações', '/configuracoes', 'Mensagens de WhatsApp'),
    ];
    for (final screen in screens) {
      await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(screen.$1)));
      await tester.pumpAndSettle();
      expect(routes.uri.path, screen.$2);
      expect(find.textContaining(screen.$3), findsWidgets);
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.widgetWithText(TextButton, 'Perfil'));
    await tester.pumpAndSettle();
    expect(routes.uri.path, '/perfil');
    expect(find.text('Seus dados de acesso'), findsOneWidget);

    expect(await routes.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(routes.uri.path, '/configuracoes');
    expect(await routes.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(routes.uri.path, '/lixeira');

    await routes.setNewRoutePath(Uri(path: '/cobrancas'));
    await tester.pumpAndSettle();
    expect(find.text('Almir'), findsWidgets);
    expect(find.text('Receber'), findsWidgets);
    expect(find.text('08/11'), findsOneWidget);

    await tester.tap(find.byTooltip('Ver detalhes').first);
    await tester.pumpAndSettle();
    expect(find.text('Parcelas deste contrato'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Lembrete: 08/11').first);
    await tester.pumpAndSettle();
    expect(find.text('Que dia o cliente prometeu pagar?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Receber').first);
    await tester.pumpAndSettle();
    expect(find.text('Registrar recebimento'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await routes.setNewRoutePath(Uri(path: '/usuarios'));
    await tester.pumpAndSettle();
    expect(routes.uri.path, '/');
    expect(find.text('Resumo da operação'), findsOneWidget);

    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await routes.setNewRoutePath(Uri(path: '/cobrancas'));
    await tester.pumpAndSettle();
    expect(find.text('Receber'), findsWidgets);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sair'));
    await tester.pumpAndSettle();
    expect(routes.uri.path, '/');
    expect(find.text('Criar conta grátis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('o administrador vê a tela de usuários', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = Repo(sqlite3.openInMemory(), ':memory:');
    addTearDown(repo.close);
    repo.setSetting('session_token', 'tok');
    final routes = AppRoutes();
    final api = AuthApi(client: MockClient((request) => _api(request, role: 'admin')));

    await tester.pumpWidget(JurosApp(repo: repo, auth: api, routes: routes));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Usuários')));
    await tester.pumpAndSettle();
    expect(routes.uri.path, '/usuarios');
    expect(find.text('Novo usuário'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<http.Response> _api(http.Request request, {required String role}) async {
  final path = request.url.path;
  if (path.endsWith('/api/login') || path.endsWith('/api/me')) {
    return http.Response(
      jsonEncode({
        'token': 'tok',
        'user': {
          'id': 1,
          'username': 'operador',
          'name': 'Operador',
          'role': role,
          'active': true,
          'access': {
            'status': 'teste',
            'days_left': 3,
            'trial_ends_at': 1,
            'paid_until': 0,
            'plan': '',
            'blocked': false,
          },
        },
      }),
      200,
    );
  }
  if (path.endsWith('/api/consultas')) {
    return http.Response('{"provider":false,"products":[],"history":[]}', 200);
  }
  if (path.endsWith('/api/users')) return http.Response('{"users":[]}', 200);
  if (path.endsWith('/api/account')) return http.Response('{"revision":0}', 200);
  if (path.endsWith('/api/settings')) return http.Response('{"settings":{}}', 200);
  return http.Response('{}', 200);
}

void _seed(Repo repo) {
  final clientId = repo.saveClient(
    name: 'Almir',
    document: '',
    phone: '86999999999',
    zip: '',
    address: '',
    workAddress: '',
  );
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
  repo.setPromiseDate(repo.installmentsOf(loanId).single.id, '2026-11-08');
}
