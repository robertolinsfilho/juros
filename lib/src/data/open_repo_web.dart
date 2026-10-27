import 'package:sqlite3/wasm.dart';

import 'repository.dart';

Future<Repo> openRepo() async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final fs = await IndexedDbFileSystem.open(dbName: 'juros');
  sqlite.registerVirtualFileSystem(fs, makeDefault: true);
  return Repo(sqlite.open('/juros.db'), 'neste navegador');
}
