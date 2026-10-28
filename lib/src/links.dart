import 'format.dart';
import 'links_web.dart' if (dart.library.ffi) 'links_io.dart';

export 'links_web.dart' if (dart.library.ffi) 'links_io.dart' show openExternal, openWhenReady;

/// Link direto. O atalho wa.me redireciona e troca os ícones por um caractere quebrado.
Uri? whatsAppUri({required String phone, required String message}) {
  final digits = digitsOnly(phone);
  if (digits.isEmpty) return null;
  final full = digits.startsWith('55') || (digits.length != 10 && digits.length != 11)
      ? digits
      : '55$digits';
  return Uri.https('api.whatsapp.com', '/send', {'phone': full, 'text': message});
}

Future<bool> openWhatsApp({required String phone, required String message}) {
  final uri = whatsAppUri(phone: phone, message: message);
  if (uri == null) return Future.value(false);
  return openExternal(uri);
}
