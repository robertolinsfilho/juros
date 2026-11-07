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

  testWidgets('o cadastro traduz os códigos do fornecedor', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ResultView(
              value: {
                'results': {
                  'cadastral': {
                    'ds_genero': 'Masculino',
                    'ds_status_cpf': 'Regular',
                    'dt_nascimento': '1990-01-02',
                    'idade': 28,
                    'nm_completo': 'MARIA SILVA',
                    'nm_mae': 'ANA SILVA',
                    'nome': [
                      {
                        'cd_ordem': 1,
                        'nm_primeiro': 'MARIA',
                        'nm_meio': 'SILVA',
                        'nm_ultimo': 'SILVA',
                      },
                    ],
                    'nr_cpf': '11144477735',
                    'sg_genero': 'M',
                    'sg_status_cpf': 'R',
                  },
                },
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Identificação'), findsOneWidget);
    expect(find.text('Nome'), findsOneWidget);
    expect(find.text('MARIA SILVA'), findsOneWidget);
    expect(find.text('CPF'), findsOneWidget);
    expect(find.text('111.444.777-35'), findsOneWidget);
    expect(find.text('Nascimento'), findsOneWidget);
    expect(find.text('02/01/1990'), findsOneWidget);
    expect(find.text('Idade'), findsOneWidget);
    expect(find.text('Gênero'), findsOneWidget);
    expect(find.text('Masculino'), findsOneWidget);
    expect(find.text('Situação do CPF'), findsOneWidget);
    expect(find.text('Regular'), findsOneWidget);
    expect(find.text('Nome da mãe'), findsOneWidget);
    expect(find.text('ANA SILVA'), findsOneWidget);
    expect(find.text('Ds genero'), findsNothing);
    expect(find.text('Nr cpf'), findsNothing);
    expect(find.text('Sg genero'), findsNothing);
    expect(find.text('Cd ordem'), findsNothing);
    expect(find.text('Nm primeiro'), findsNothing);
    expect(find.text('Results'), findsNothing);
  });

  testWidgets('o cadastro de empresa e os endereços do CPF aparecem', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ResultView(
              value: {
                'results': {
                  'contato': {
                    'endereco': [
                      {
                        'ds_logradouro': 'RUA PROFESSORA ZULMIRA',
                        'nr_numero': '101',
                        'ds_bairro': 'CHARQUEADAS',
                        'ds_cidade': 'CAXIAS DO SUL',
                        'sg_uf': 'RS',
                        'nr_cep': '95110151',
                      },
                    ],
                  },
                },
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RUA PROFESSORA ZULMIRA'), findsOneWidget);
    expect(find.text('CAXIAS DO SUL'), findsOneWidget);
    expect(find.text('95110-151'), findsOneWidget);
    expect(find.text('A consulta não trouxe registros.'), findsNothing);
  });

  testWidgets('os processos do CNPJ aparecem com número, partes e PDF', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ResultView(
              value: {
                'dados': {
                  'quantidade_acoes': 1,
                  'quantidade_arquivadas': 0,
                  'acoes': [
                    {
                      'tribunal': 'TJSP',
                      'grau': 'GRAU 1',
                      'numero_processo': '0001234-56.2023.8.26.0100',
                      'classe': 'PROCEDIMENTO COMUM CIVEL',
                      'assunto': 'INADIMPLEMENTO',
                      'valor': '15000,00',
                      'data_distribuicao': '14/03/2023',
                      'uf': 'SP',
                      'segredo_justica': 'NAO',
                      'partes': [
                        {
                          'nome': 'BANCO EXEMPLO S.A.',
                          'documento': '00000000000191',
                          'tipo': 'AUTOR',
                          'polo': 'ATIVO',
                        },
                      ],
                      'status': {'status_processo': 'EM ANDAMENTO'},
                    },
                  ],
                  'acoes_arquivadas': [],
                  'pdf': 'https://example.com/processos.pdf',
                },
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Processos ativos'), findsOneWidget);
    expect(find.text('0001234-56.2023.8.26.0100'), findsOneWidget);
    expect(find.text('TJSP'), findsOneWidget);
    expect(find.text('INADIMPLEMENTO'), findsOneWidget);
    expect(find.text('R\$ 15.000,00'), findsOneWidget);
    expect(find.text('Não'), findsOneWidget);
    expect(find.text('BANCO EXEMPLO S.A.'), findsOneWidget);
    expect(find.text('00.000.000/0001-91'), findsOneWidget);
    expect(find.text('EM ANDAMENTO'), findsOneWidget);
    expect(find.text('Abrir PDF'), findsOneWidget);
    expect(find.text('Arquivados'), findsNothing);
  });
}
