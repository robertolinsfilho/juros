import 'format.dart';
import 'links_web.dart' if (dart.library.ffi) 'links_io.dart';

export 'links_web.dart' if (dart.library.ffi) 'links_io.dart' show openExternal, openWhenReady;

Future<bool> openWhatsApp({required String phone, required String message}) {
  final digits = digitsOnly(phone);
  if (digits.isEmpty) return Future.value(false);
  final full = digits.startsWith('55') || (digits.length != 10 && digits.length != 11)
      ? digits
      : '55$digits';
  final uri = Uri.parse('https://wa.me/$full?text=${Uri.encodeComponent(message)}');
  return openExternal(uri);
}
