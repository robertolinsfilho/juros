import 'package:web/web.dart' as web;

const _key = 'juros.session';

String readSession() => web.window.localStorage.getItem(_key) ?? '';

void writeSession(String token) {
  if (token.isEmpty) {
    web.window.localStorage.removeItem(_key);
    return;
  }
  web.window.localStorage.setItem(_key, token);
}
