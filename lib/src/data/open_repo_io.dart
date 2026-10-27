import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'repository.dart';

Future<Repo> openRepo() async {
  final root = Platform.environment['APPDATA'] ?? Directory.current.path;
  final dir = Directory(p.join(root, 'Juros'));
  dir.createSync(recursive: true);
  final path = p.join(dir.path, 'juros.db');
  return Repo(sqlite3.open(path), path);
}
