import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juros/src/app.dart';
import 'package:juros/src/app_routes.dart';
import 'package:juros/src/auth/auth_api.dart';
import 'package:juros/src/data/repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  testWidgets('voltar e recarregar ficam na tela aberta', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = Repo(sqlite3.openInMemory(), ':memory:');
    addTearDown(repo.close);
    repo.setSetting('session_token', 'tok');
    final routes = AppRoutes();
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
        return http.Response('{"settings":{}}', 200);
      }),
    );

    await tester.pumpWidget(JurosApp(repo: repo, auth: api, routes: routes));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsWidgets);
    expect(routes.uri.path, '/');

    await tester.tap(find.text('Cobranças'));
    await tester.pumpAndSettle();
    expect(routes.uri.path, '/cobrancas');
    expect(find.text('Quem não pagou'), findsOneWidget);

    await routes.setNewRoutePath(Uri(path: '/'));
    await tester.pumpAndSettle();
    expect(routes.uri.path, '/');
    expect(find.text('Quem não pagou'), findsNothing);
    expect(find.text('Dashboard'), findsWidgets);

    await routes.setNewRoutePath(Uri(path: '/cobrancas'));
    await tester.pumpAndSettle();
    expect(find.text('Quem não pagou'), findsOneWidget);
  });
}
