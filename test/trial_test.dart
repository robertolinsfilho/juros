import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juros/src/auth/auth_api.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/plans_dialog.dart';
import 'package:juros/src/ui/trial_widgets.dart';

AuthApi api({String message = 'Pedido registrado. Fale com o suporte.'}) {
  return AuthApi(
    client: MockClient((request) async {
      if (request.url.path.endsWith('/api/subscribe')) {
        return http.Response('{"requested":true,"checkout_url":"","message":"$message"}', 200);
      }
      return http.Response('{}', 404);
    }),
  );
}

void main() {
  testWidgets('aviso de teste mostra os dias e chama o assinar', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Column(
            children: [
              TrialBar(text: 'Teste gratuito — 3 dias restantes', onSubscribe: () => taps++),
              TrialNotice(daysLeft: 3, onSubscribe: () => taps++),
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining('Teste gratuito — 3 dias restantes'), findsOneWidget);
    expect(find.textContaining('Modo de teste — 3 dias restantes'), findsOneWidget);
    await tester.tap(find.text('Assinar agora →'));
    await tester.tap(find.text('Assinar'));
    expect(taps, 2);
  });

  testWidgets('modal de planos lista os dois planos e registra o pedido', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showPlansDialog(context, auth: api(), token: 't', daysLeft: 3),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Planos e Assinatura'), findsOneWidget);
    expect(find.text('Plano Mensal'), findsOneWidget);
    expect(find.text('Aplicativo + Relatório'), findsOneWidget);
    expect(find.textContaining('3 dias'), findsWidgets);
    await tester.tap(find.text('Assinar agora').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Pedido registrado'), findsOneWidget);
  });

  testWidgets('teste encerrado muda o aviso', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: TrialNotice(daysLeft: 0, onSubscribe: () {}),
        ),
      ),
    );
    expect(find.textContaining('encerrado'), findsOneWidget);
  });
}
