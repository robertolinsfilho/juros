import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juros/src/auth/auth_api.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/profile_page.dart';

SessionUser person({required String status, String plan = ''}) {
  return SessionUser(
    id: 2,
    username: 'operador',
    name: 'Operador',
    role: 'comum',
    active: true,
    access: AccessInfo(
      status: status,
      daysLeft: status == 'assinante' ? 20 : 2,
      trialEndsAt: 1,
      paidUntil: status == 'assinante' ? 999 : 0,
      plan: plan,
      blocked: false,
    ),
  );
}

void main() {
  testWidgets('quem tem assinatura ativa pode cancelar no perfil', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var posted = 0;
    SessionUser? updated;
    final api = AuthApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/me/cancel');
        posted += 1;
        return http.Response(
          jsonEncode({
            'user': {
              'id': 2,
              'username': 'operador',
              'name': 'Operador',
              'role': 'comum',
              'active': true,
              'access': {
                'status': 'vencido',
                'days_left': 0,
                'trial_ends_at': 1,
                'paid_until': 0,
                'plan': '',
                'blocked': true,
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    Future<void> pump(SessionUser user) {
      return tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: ProfilePage(
              auth: api,
              token: 'tok',
              user: user,
              onUpdated: (next) => updated = next,
            ),
          ),
        ),
      );
    }

    await pump(person(status: 'teste'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar assinatura'), findsNothing);

    await pump(person(status: 'assinante', plan: 'cortesia'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar assinatura'), findsNothing);

    await pump(person(status: 'assinante', plan: 'mensal'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar assinatura'));
    await tester.pumpAndSettle();
    expect(find.text('Manter assinatura'), findsOneWidget);
    await tester.tap(find.text('Manter assinatura'));
    await tester.pumpAndSettle();
    expect(posted, 0);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar assinatura'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar assinatura'));
    await tester.pumpAndSettle();
    expect(posted, 1);
    expect(updated?.access.status, 'vencido');
    expect(updated?.access.blocked, isTrue);
  });
}
