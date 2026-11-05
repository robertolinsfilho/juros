import 'dart:convert';
import 'dart:io';

({String user, String password, bool remember}) _memory = (user: '', password: '', remember: true);

bool get _testing => Platform.resolvedExecutable.contains('flutter_tester');

File? _file() {
  if (_testing) return null;
  final root = Platform.environment['APPDATA'] ?? Platform.environment['HOME'];
  if (root == null || root.isEmpty) return null;
  final sep = Platform.pathSeparator;
  final dir = Directory(root.endsWith(sep) ? '${root}Juros' : '$root${sep}Juros');
  dir.createSync(recursive: true);
  return File('${dir.path}${sep}login.json');
}

({String user, String password, bool remember}) _fromMap(Map data) {
  final remember = data['remember'] != false;
  if (!remember) return (user: '', password: '', remember: false);
  return (
    user: data['user'] is String ? data['user'] as String : '',
    password: data['password'] is String ? data['password'] as String : '',
    remember: true,
  );
}

({String user, String password, bool remember}) readSavedLogin() {
  final file = _file();
  if (file == null) return _memory;
  if (!file.existsSync()) return (user: '', password: '', remember: true);
  try {
    final data = jsonDecode(file.readAsStringSync());
    if (data is! Map) return (user: '', password: '', remember: true);
    return _fromMap(data);
  } catch (_) {
    return (user: '', password: '', remember: true);
  }
}

void writeSavedLogin(String user, String password, {required bool remember}) {
  final next = !remember || user.isEmpty
      ? (user: '', password: '', remember: remember)
      : (user: user, password: password, remember: true);
  final file = _file();
  if (file == null) {
    _memory = next;
    return;
  }
  file.writeAsStringSync(jsonEncode({'user': next.user, 'password': next.password, 'remember': next.remember}));
}

void resetSavedLogin() {
  _memory = (user: '', password: '', remember: true);
  final file = _file();
  if (file != null && file.existsSync()) file.deleteSync();
}
