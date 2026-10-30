import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juros/src/auth/account_sync.dart';
import 'package:juros/src/auth/auth_api.dart';
import 'package:juros/src/data/repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('o celular recebe a conta que o computador gravou', () async {
    final computer = Repo(sqlite3.openInMemory(), ':memory:');
    final phone = Repo(sqlite3.openInMemory(), ':memory:');
    addTearDown(computer.close);
    addTearDown(phone.close);
    computer.saveClient(
      name: 'Maria',
      document: '',
      phone: '86999999999',
      zip: '',
      address: '',
      workAddress: '',
    );
    computer.setSetting('session_token', 'segredo');
    var revision = 0;
    Map<String, dynamic>? stored;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'revision': revision, 'updated_at': 1, 'data': stored}),
          200,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final base = body['base'] as int;
      if (base != revision) {
        return http.Response(
          jsonEncode({
            'error': 'Os dados mudaram em outro aparelho.',
            'revision': revision,
            'data': stored,
          }),
          409,
        );
      }
      revision += 1;
      stored = (body['data'] as Map).cast<String, dynamic>();
      expect(stored!['settings'], isNot(contains('session_token')));
      return http.Response(jsonEncode({'revision': revision, 'updated_at': 2}), 200);
    });
    final api = AuthApi(client: client);
    await AccountSync(computer, api, interval: const Duration(hours: 1)).start('tok');
    expect(revision, 1);
    await AccountSync(phone, api, interval: const Duration(hours: 1)).start('tok');
    expect(phone.listClients().map((item) => item.name), ['Maria']);
    expect(phone.setting('session_token'), isEmpty);
  });
}