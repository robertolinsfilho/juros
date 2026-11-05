import 'login_store_web.dart' if (dart.library.ffi) 'login_store_io.dart' as impl;

typedef SavedLogin = ({String user, String password, bool remember});

SavedLogin readSavedLogin() => impl.readSavedLogin();

void writeSavedLogin(String user, String password, {required bool remember}) =>
    impl.writeSavedLogin(user, password, remember: remember);

void resetSavedLogin() => impl.resetSavedLogin();
