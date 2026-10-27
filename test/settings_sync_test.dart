import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juros/src/auth/auth_api.dart';
import 'package:juros/src/auth/settings_sync.dart';
import 'package:juros/src/data/repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Repo repo;
  late Map<String, String> server;
  late List<Map<String, dynamic>> posts;
  late bool offline;
  late SettingsSync sync;

  setUp(() {
    repo = Repo(sqlite3.openInMemory(), ':memory:');
    server = {};
    posts = [];
    offline = false;
    final client = MockClient((request) async {
      if (offline) throw http.ClientException('sem rede');
      if (request.url.path.endsWith('/api/settings') && request.method == 'GET') {
        return http.Response(jsonEncode({'settings': server}), 200);
      }
      if (request.url.path.endsWith('/api/settings') && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final changes = (body['settings'] as Map).cast<String, String?>();
        posts.add(changes);
        changes.forEach((key, value) {
          if (value == null) {
            server.remove(key);
          } else {
            server[key] = value;
          }
        });
        return http.Response('{"ok":true}', 200);
      }
      return http.Response('{}', 404);
    });
    sync = SettingsSync(repo, AuthApi(client: client), delay: Duration.zero);
  });
  tearDown(() => repo.close());

  test('conta sem ajustes recebe os que já estavam neste navegador', () async {
    repo.setSetting('creditor_name', 'Roberto');
    repo.setSetting('session_token', 'segredo');
    await sync.start('t');
    expect(server, {'creditor_name': 'Roberto'});
  });

  test('ajustes do servidor substituem os locais', () async {
    repo.setSetting('creditor_name', 'Antigo');
    repo.setSetting('sig_fraction', '1');
    server = {'creditor_name': 'Do servidor'};
    await sync.start('t');
    expect(repo.setting('creditor_name'), 'Do servidor');
    expect(repo.setting('sig_fraction', 'x'), 'x');
    expect(posts, isEmpty);
  });

  test('mudança de ajuste pessoal é enviada; a sessão não', () async {
    await sync.start('t');
    repo.setSetting('msg_tpl_atrasado', 'oi');
    repo.setSetting('session_token', 'abc');
    expect(await sync.flush(), isTrue);
    expect(server, {'msg_tpl_atrasado': 'oi'});
    repo.setSetting('msg_tpl_atrasado', '');
    await sync.flush();
    expect(server['msg_tpl_atrasado'], '');
  });

  test('sair envia o que falta e limpa os ajustes pessoais', () async {
    await sync.start('t');
    repo.setSetting('pix_key', 'chave');
    repo.setSetting('session_token', 'abc');
    await sync.stop();
    expect(server['pix_key'], 'chave');
    expect(repo.setting('pix_key', 'vazio'), 'vazio');
    expect(repo.setting('session_token'), 'abc');
  });

  test('sem rede ao sair, mantém os ajustes locais', () async {
    await sync.start('t');
    repo.setSetting('pix_key', 'chave');
    offline = true;
    await sync.stop();
    expect(repo.setting('pix_key'), 'chave');
  });

  test('só chaves pessoais são sincronizadas', () {
    expect(isSyncedSetting('creditor_name'), isTrue);
    expect(isSyncedSetting('msg_active_atrasado'), isTrue);
    expect(isSyncedSetting('session_token'), isFalse);
  });
}
