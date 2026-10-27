import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/landing_page.dart';

Future<void> open(WidgetTester tester, Size size, VoidCallback onEnter) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: LandingPage(onEnter: onEnter)));
}

void main() {
  for (final size in const [Size(1400, 900), Size(390, 800)]) {
    testWidgets('home renderiza sem estouro em ${size.width.toInt()}px', (tester) async {
      await open(tester, size, () {});
      expect(find.text('Entrar no sistema'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Perguntas frequentes'), 600, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Funciona no celular?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('adicione à tela inicial'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('botões levam ao login', (tester) async {
    var taps = 0;
    await open(tester, const Size(1400, 900), () => taps++);
    await tester.tap(find.text('Acessar'));
    await tester.tap(find.text('Entrar'));
    await tester.tap(find.text('Entrar no sistema').first);
    expect(taps, 3);
  });

  testWidgets('Ver como funciona rola até as funcionalidades', (tester) async {
    await open(tester, const Size(1400, 900), () {});
    await tester.tap(find.text('Ver como funciona'));
    await tester.pumpAndSettle();
    expect(find.text('Tudo que o dia a dia pede, sem complicação').hitTestable(), findsOneWidget);
  });
}
