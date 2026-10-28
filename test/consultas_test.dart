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

  testWidgets('o resultado da consulta aparece em blocos', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ResultView(
              value: {
                'dados': [
                  {
                    'acertaEssencialPositivo': {
                      'consultaCredito': {
                        'dadosCadastrais': {
                          'nome': 'MARIA SILVA',
                          'cpf': '11144477735',
                          'dataNascimento': '1990-01-02',
                          'cep': '31030071',
                          'telefone': '11987654321',
                        },
                        'score': {'score': 720, 'texto': 'Baixo risco'},
                        'protestos': [
                          {'cartorio': '1º Ofício', 'valor': 1200.5, 'data': '2024-03-12'},
                        ],
                        'pdf': 'https://example.com/relatorio.pdf',
                      },
                    },
                  },
                ],
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dados cadastrais'), findsOneWidget);
    expect(find.text('MARIA SILVA'), findsOneWidget);
    expect(find.text('111.444.777-35'), findsOneWidget);
    expect(find.text('02/01/1990'), findsOneWidget);
    expect(find.text('31030-071'), findsOneWidget);
    expect(find.text('(11) 98765-4321'), findsOneWidget);
    expect(find.text('720'), findsWidgets);
    expect(find.text('Baixo risco'), findsWidgets);
    expect(find.text('R\$ 1.200,50'), findsOneWidget);
    expect(find.text('12/03/2024'), findsOneWidget);
    expect(find.text('Abrir PDF'), findsOneWidget);
    expect(find.text('acertaEssencialPositivo'), findsNothing);
    expect(find.textContaining('{'), findsNothing);
  });
}
