import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/links.dart';

void main() {
  test('cobrança abre o WhatsApp sem passar pelo atalho que quebra ícone', () {
    const message = 'Olá, roberto! 👋\n🔔 LEMBRETE';
    final uri = whatsAppUri(phone: '81999999999', message: message)!;
    expect(uri.host, 'api.whatsapp.com');
    expect(uri.path, '/send');
    expect(uri.queryParameters['phone'], '5581999999999');
    expect(uri.queryParameters['text'], message);
    expect(uri.toString(), contains('%F0%9F%91%8B'));
    expect(uri.toString(), isNot(contains('wa.me')));
    expect(uri.toString(), isNot(contains('%EF%BF%BD')));
  });
}
