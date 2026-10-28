import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/landing_page.dart';

Future<void> open(WidgetTester tester, Size size, {VoidCallback? onCreate, VoidCallback? onLogin}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: LandingPage(onCreate: onCreate ?? () {}, onLogin: onLogin ?? () {}),
    ),
  );
}

void main() {
  test('o site usa Plus Jakarta Sans', () {
    final theme = buildTheme();
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Plus Jakarta Sans');
    expect(theme.textTheme.headlineMedium?.fontFamily, 'Plus Jakarta Sans');
    expect(theme.textTheme.bodyMedium?.fontFamilyFallback, contains('NotoEmoji'));
  });

  for (final size in const [Size(1400, 900), Size(390, 800)]) {
    testWidgets('home renderiza sem estouro em ${size.width.toInt()}px', (tester) async {
      await open(tester, size);
      expect(find.textContaining('Criar conta grátis'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Perguntas frequentes'), 600, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Funciona no celular?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('adicione à tela inicial'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('criar conta e entrar vão para lugares diferentes', (tester) async {
    var created = 0;
    var logins = 0;
    await open(tester, const Size(1400, 900), onCreate: () => created++, onLogin: () => logins++);
    await tester.tap(find.text('Criar conta grátis'));
    await tester.tap(find.text('Entrar'));
    await tester.tap(find.textContaining('Criar conta grátis por 3 dias').first);
    expect(created, 2);
    expect(logins, 1);
  });

  testWidgets('Ver como funciona rola até as funcionalidades', (tester) async {
    await open(tester, const Size(1400, 900));
    await tester.tap(find.text('Ver como funciona'));
    await tester.pumpAndSettle();
    expect(find.text('Tudo que o dia a dia pede, sem complicação').hitTestable(), findsOneWidget);
  });
}
