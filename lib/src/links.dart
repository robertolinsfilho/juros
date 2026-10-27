import 'format.dart';
import 'links_web.dart' if (dart.library.ffi) 'links_io.dart';

String chargeMessage({
  required String client,
  required int number,
  required int count,
  required int cents,
  required String dueIso,
  required String creditor,
  required String pix,
  int lateCents = 0,
}) {
  final late = lateCents > 0 ? ' Mora: ${fmtMoney(lateCents)}.' : '';
  final pixLine = pix.isEmpty ? '' : '\nPIX: $pix';
  final sign = creditor.isEmpty ? '' : '\n$creditor';
  return 'Olá $client. A parcela $number/$count de ${fmtMoney(cents)} vence em ${fmtDateIso(dueIso)}.$late$pixLine$sign';
}

Future<bool> openWhatsApp({required String phone, required String message}) {
  final digits = digitsOnly(phone);
  if (digits.isEmpty) return Future.value(false);
  final full = digits.startsWith('55') || (digits.length != 10 && digits.length != 11)
      ? digits
      : '55$digits';
  final uri = Uri.parse('https://wa.me/$full?text=${Uri.encodeComponent(message)}');
  return openExternal(uri);
}
