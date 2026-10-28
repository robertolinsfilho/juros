import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juros/src/auth/auth_api.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/profile_page.dart';

SessionUser client({String email = 'maria@example.com'}) {
  return SessionUser(
    id: 4,
    username: 'maria',
    name: 'Maria',
    role: 'comum',
    active: true,
    email: email,
    access: const AccessInfo(
      status: 'assinante',
      daysLeft: 10,
      trialEndsAt: 1,
      paidUntil: 999,
      plan: 'mensal',
      blocked: false,
    ),
  );
}

void main() {
  testWidgets('trocar a senha pede o código do e-mail cadastrado', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final posts = <String>[];
    final api = AuthApi(
      client: MockClient((request) async {
        posts.add(request.url.path);
        if (request.url.path == '/api/me/password-code') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['current'], 'atual123');
          expect(body['password'], 'nova1234');
          return http.Response(
            jsonEncode({'sent': true, 'email': 'm***@example.com'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['code'], '123456');
        expect(body['password'], 'nova1234');
        return http.Response(jsonEncode({'ok': true}), 200, headers: {'content-type': 'application/json'});
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ProfilePage(auth: api, token: 'tok', user: client(), onUpdated: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enviar código'), findsOneWidget);
    expect(find.text('Código do e-mail'), findsNothing);
    final change = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Trocar senha'));
    expect(change.onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Senha atual'), 'atual123');
    await tester.enterText(find.widgetWithText(TextField, 'Nova senha'), 'nova1234');
    await tester.enterText(find.widgetWithText(TextField, 'Confirmar nova senha'), 'nova1234');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    expect(posts, ['/api/me/password-code']);
    expect(find.text('Código enviado para m***@example.com.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Código do e-mail'), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Trocar senha'));
    await tester.pumpAndSettle();

    expect(posts, ['/api/me/password-code', '/api/users/4/password']);
    expect(find.text('Senha atualizada.'), findsOneWidget);
  });
}
