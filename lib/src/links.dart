import 'data/repository.dart';
import 'format.dart';
import 'links_web.dart' if (dart.library.ffi) 'links_io.dart';

String _plural(int days) => days == 1 ? '1 dia' : '$days dias';

/// Texto de cobrança que muda conforme a situação da parcela:
/// antes do vencimento, vence hoje ou em atraso.
String chargeMessage(
  InstallmentRecord item, {
  required String creditor,
  required String pix,
  DateTime? today,
}) {
  final now = dateOnly(today ?? DateTime.now());
  final due = parseIsoDate(item.dueDate);
  final days = due.difference(now).inDays;
  final late = item.liveLateCents(now);
  final interestOnly = item.principalCents == 0 && item.interestCents > 0;
  final what = interestOnly ? 'o pagamento dos juros' : 'a parcela ${item.number}/${item.count}';
  final buffer = StringBuffer();

  if (days > 0) {
    buffer
      ..writeln('Olá, *${item.clientName}*! 👋')
      ..writeln('Passando para lembrar de $what, que vence em ${_plural(days)}.');
  } else if (days == 0) {
    buffer
      ..writeln('Olá, *${item.clientName}*! 👋')
      ..writeln('Hoje vence $what.');
  } else {
    buffer
      ..writeln('Olá, *${item.clientName}*.')
      ..writeln('Consta em aberto $what, em atraso há ${_plural(-days)}.');
  }

  buffer
    ..writeln()
    ..writeln('💵 Valor: *${fmtMoney(item.faceCents)}*')
    ..writeln('📅 Vencimento: *${fmtDateIso(item.dueDate)}*');
  if (late > 0) {
    buffer
      ..writeln('⚠️ Mora: *${fmtMoney(late)}*')
      ..writeln('🧾 Total atualizado: *${fmtMoney(item.faceCents + late)}*');
  }
  if (pix.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('💳 PIX: $pix');
  }
  buffer
    ..writeln()
    ..write(days < 0 ? 'Podemos combinar o pagamento? Me responda por aqui.' : 'Se já pagou, desconsidere esta mensagem.');
  if (creditor.isNotEmpty) buffer.write('\n$creditor');
  return buffer.toString();
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
