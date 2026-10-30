import 'package:sqlite3/wasm.dart';

import '../auth/session_store.dart';
import 'repository.dart';

Future<Repo> openRepo() async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  Map<String, dynamic>? legacy;
  var token = '';
  var hadLegacy = false;
  try {
    final names = await IndexedDbFileSystem.databases();
    hadLegacy = names?.contains('juros') ?? false;
  } catch (_) {
    hadLegacy = false;
  }
  if (hadLegacy) {
    try {
      final fs = await IndexedDbFileSystem.open(dbName: 'juros');
      sqlite.registerVirtualFileSystem(fs);
      final stored = Repo(sqlite.open('/juros.db', vfs: fs.name), 'legado');
      legacy = stored.accountSnapshot();
      token = stored.setting('session_token');
      stored.close();
      await fs.close();
    } catch (_) {
      legacy = null;
    }
  }
  final repo = Repo(sqlite.openInMemory(), 'na conta');
  if (legacy != null) repo.replaceAccount(legacy);
  if (token.isNotEmpty) {
    writeSession(token);
    repo.setSetting('session_token', token);
  }
  if (hadLegacy) {
    repo.discardLegacy = () async {
      try {
        await IndexedDbFileSystem.deleteDatabase('juros');
      } catch (_) {}
    };
  }
  return repo;
}
