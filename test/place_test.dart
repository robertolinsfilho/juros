import 'package:flutter_test/flutter_test.dart';
import 'package:juros/src/place.dart';

void main() {
  test('cada tela tem um endereço e a volta do pagamento abre consultas', () {
    expect(pathForSection(0), '/');
    expect(pathForSection(1), '/cobrancas');
    expect(sectionForPath('/cobrancas'), 1);
    expect(sectionForPath('/clientes'), 2);
    expect(sectionForPath('/consultas'), 10);
    expect(sectionForPath('/perfil'), 9);
    expect(sectionForPath('/nao-existe'), 0);
    expect(trySection('/nao-existe'), isNull);

    expect(sectionForLocation('/'), 0);
    expect(sectionForLocation('/', consulta: 'ok'), 10);
    expect(sectionForLocation('/', consulta: 'pendente'), 10);
    expect(sectionForLocation('/cobrancas', consulta: 'ok'), 1);
    expect(sectionForLocation('/', consulta: 'ok', honorConsulta: false), 0);
    expect(isAuthPath('/entrar'), isTrue);
    expect(isAuthPath('/criar'), isTrue);
    expect(isAuthPath('/cobrancas'), isFalse);
  });
}
