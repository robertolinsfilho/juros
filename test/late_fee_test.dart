import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/theme.dart';
import 'package:juros/src/ui/late_fee_fields.dart';

void main() {
  testWidgets('em % ao dia mostra taxa, dica e texto do WhatsApp', (tester) async {
    final percent = TextEditingController(text: '1');
    final daily = TextEditingController();
    final fixed = TextEditingController();
    final explain = TextEditingController(
      text: '*Se atrasar:* a cada dia de atraso, cada parcela em aberto soma 1% ao dia sobre o valor dela (mora).',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: LateFeeFields(
            mode: 'percentual_dia',
            onMode: (_) {},
            percent: percent,
            daily: daily,
            fixed: fixed,
            explain: true,
            onExplain: (_) {},
            explainText: explain,
            onExplainEdited: () {},
            onValuesChanged: () {},
          ),
        ),
      ),
    );
    expect(find.text('Juros por atraso (mora)'), findsOneWidget);
    expect(find.text('Taxa (% ao dia)'), findsOneWidget);
    expect(find.textContaining('Sugerido: 1% ao dia'), findsOneWidget);
    expect(find.text('Enviar explicação da mora no WhatsApp'), findsOneWidget);
    expect(find.textContaining('no fim das mensagens de cobrança e da situação'), findsOneWidget);
    expect(find.text('Texto da explicação'), findsOneWidget);
    expect(find.textContaining('soma 1% ao dia sobre o valor dela'), findsOneWidget);
    percent.dispose();
    daily.dispose();
    fixed.dispose();
    explain.dispose();
  });
}
