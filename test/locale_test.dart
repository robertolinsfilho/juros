import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('o calendário abre em português', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            final labels = MaterialLocalizations.of(context);
            return Text('${labels.datePickerHelpText}|${labels.formatMonthYear(DateTime(2026, 10))}');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Selecione a data'), findsOneWidget);
    expect(find.textContaining('outubro'), findsOneWidget);
  });
}
