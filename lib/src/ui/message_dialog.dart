import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repository.dart';
import '../links.dart';
import '../messages/builders.dart';
import '../theme.dart';
import 'widgets.dart';

/// Mostra o texto como no WhatsApp: *negrito* e _itálico_.
class WhatsAppText extends StatelessWidget {
  const WhatsAppText(this.text, {super.key});

  final String text;

  List<InlineSpan> _spans(TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*([^*\n]+)\*|_([^_\n]+)_');
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) spans.add(TextSpan(text: text.substring(cursor, match.start)));
      if (match.group(1) != null) {
        spans.add(TextSpan(text: match.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else {
        spans.add(TextSpan(text: match.group(2), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: SelectableText.rich(TextSpan(style: base.copyWith(height: 1.35), children: _spans(base))),
    );
  }
}

Future<void> showMessageDialog(
  BuildContext context, {
  required String title,
  required String text,
  required String phone,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(child: WhatsAppText(text)),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text.replaceAll('*', '').replaceAll('_', '')));
            if (context.mounted) showError(context, 'Mensagem copiada.');
          },
          child: const Text('Copiar'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        FilledButton(
          onPressed: () async {
            final opened = await openWhatsApp(phone: phone, message: text);
            if (!opened && context.mounted) {
              showError(context, 'Cliente sem telefone válido. Cadastre o WhatsApp do cliente.');
            }
          },
          child: const Text('Enviar via WhatsApp'),
        ),
      ],
    ),
  );
}

/// Depois de registrar um recebimento, oferece enviar a confirmação ao cliente.
Future<void> offerPaymentMessage(BuildContext context, Repo repo, InstallmentRecord item) async {
  final send = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Recebimento registrado'),
      content: Text('Enviar a confirmação para ${item.clientName} pelo WhatsApp?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Agora não')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ver mensagem')),
      ],
    ),
  );
  if (send != true || !context.mounted) return;
  await showMessageDialog(
    context,
    title: 'Confirmação de pagamento',
    text: MessageBuilder(repo).payment(item),
    phone: item.clientPhone,
  );
}
