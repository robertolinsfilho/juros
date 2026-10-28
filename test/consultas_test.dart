import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juros/src/auth/auth_api.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/consultas_page.dart';

void main() {
  testWidgets('a aba lista as consultas e não abre o pagamento sem o fornecedor', (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var posted = false;
    final api = AuthApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/consultas');
        if (request.method == 'POST') posted = true;
        return http.Response(
          jsonEncode({
            'provider': false,
            'products': [
              {
                'slug': 'localizador',
                'title': 'Localizador',
                'summary': 'Encontra a pessoa a partir do telefone ou do e-mail.',
                'cents': 990,
                'inputs': [
                  {'id': 'telefone', 'label': 'Telefone'},
                  {'id': 'email', 'label': 'E-mail'},
                ],
                'bullets': ['Nome e CPF'],
              },
            ],
            'history': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: ConsultasPage(auth: api, token: 'tok')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Localizador'), findsOneWidget);
    expect(find.text('R\$ 9,90'), findsOneWidget);
    expect(find.text('Nenhuma consulta realizada ainda.'), findsNothing);

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma consulta realizada ainda.'), findsOneWidget);

    await tester.tap(find.text('Marketplace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();
    expect(find.text('Pagar e consultar'), findsOneWidget);

    await tester.tap(find.text('Pagar e consultar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('não foi aberto'), findsOneWidget);
    expect(posted, isFalse);
  });
}
