import 'package:web/web.dart' as web;

const _user = 'juros.login.user';
const _pass = 'juros.login.pass';
const _remember = 'juros.login.remember';

({String user, String password, bool remember}) readSavedLogin() {
  final remember = web.window.localStorage.getItem(_remember) != '0';
  if (!remember) return (user: '', password: '', remember: false);
  return (
    user: web.window.localStorage.getItem(_user) ?? '',
    password: web.window.localStorage.getItem(_pass) ?? '',
    remember: true,
  );
}

void writeSavedLogin(String user, String password, {required bool remember}) {
  if (!remember || user.isEmpty) {
    web.window.localStorage.removeItem(_user);
    web.window.localStorage.removeItem(_pass);
    web.window.localStorage.setItem(_remember, remember ? '1' : '0');
    return;
  }
  web.window.localStorage.setItem(_user, user);
  web.window.localStorage.setItem(_pass, password);
  web.window.localStorage.setItem(_remember, '1');
}

void resetSavedLogin() {
  web.window.localStorage.removeItem(_user);
  web.window.localStorage.removeItem(_pass);
  web.window.localStorage.removeItem(_remember);
}
