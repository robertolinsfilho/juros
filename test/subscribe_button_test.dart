import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juros/src/app.dart';
import 'package:juros/src/auth/auth_api.dart';
import 'package:juros/src/data/repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  testWidgets('botão assinar abre o modal de planos', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = Repo(sqlite3.openInMemory(), ':memory:');
    addTearDown(repo.close);
    repo.setSetting('session_token', 'tok');
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/api/me')) {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 1,
                'username': 'operador',
                'name': 'Operador',
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
        }
        if (request.url.path.endsWith('/api/settings')) {
          return http.Response('{"settings":{}}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    await tester.pumpWidget(JurosApp(repo: repo, auth: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assinar agora →'));
    await tester.pumpAndSettle();
    expect(find.text('Planos e Assinatura'), findsOneWidget);
    expect(find.text('Plano Mensal'), findsOneWidget);
    expect(find.text('R\$ 49,99/mês'), findsOneWidget);
    expect(find.text('Aplicativo + Relatório'), findsOneWidget);
    expect(find.textContaining('3 dia(s)'), findsOneWidget);
  });
}
