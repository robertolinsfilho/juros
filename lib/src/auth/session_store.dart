import 'session_store_web.dart' if (dart.library.ffi) 'session_store_io.dart' as impl;

String readSession() => impl.readSession();

void writeSession(String token) => impl.writeSession(token);
