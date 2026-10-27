import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juros/src/auth/auth_api.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/signup_page.dart';

void main() {
  testWidgets('formulário cria a conta e entra com o teste de 3 dias', (tester) async {
    SessionUser? created;
    final api = AuthApi(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['username'], 'maria');
        expect(request.url.path, endsWith('/api/signup'));
        return http.Response(
          jsonEncode({
            'token': 'tok',
            'user': {
              'id': 9,
              'username': 'maria',
              'name': 'Maria',
              'role': 'comum',
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
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: SignupPage(
          auth: api,
          onSuccess: (user, token) {
            created = user;
            expect(token, 'tok');
          },
        ),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Seu nome'), 'Maria');
    await tester.enterText(find.widgetWithText(TextField, 'Usuário para entrar'), 'maria');
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'senha123');
    await tester.enterText(find.widgetWithText(TextField, 'Confirmar senha'), 'senha123');
    await tester.tap(find.text('Criar conta grátis por 3 dias'));
    await tester.pump();
    expect(created?.access.trial, isTrue);
    expect(created?.access.daysLeft, 3);
  });

  testWidgets('senhas diferentes não criam a conta', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var called = false;
    final api = AuthApi(client: MockClient((_) async {
      called = true;
      return http.Response('{}', 500);
    }));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: SignupPage(auth: api, onSuccess: (_, _) {}),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Seu nome'), 'Maria');
    await tester.enterText(find.widgetWithText(TextField, 'Usuário para entrar'), 'maria');
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'senha123');
    await tester.enterText(find.widgetWithText(TextField, 'Confirmar senha'), 'outra');
    await tester.ensureVisible(find.text('Criar conta grátis por 3 dias'));
    await tester.tap(find.text('Criar conta grátis por 3 dias'));
    await tester.pump();
    expect(find.textContaining('não confere'), findsOneWidget);
    expect(called, isFalse);
  });
}
