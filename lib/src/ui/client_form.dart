import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../format.dart';
import 'widgets.dart';

Future<bool> showClientForm(BuildContext context, Repo repo, {ClientRecord? client}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ClientDialog(repo: repo, client: client),
  ).then((value) => value ?? false);
}

class _ClientDialog extends StatefulWidget {
  const _ClientDialog({required this.repo, this.client});

  final Repo repo;
  final ClientRecord? client;

  @override
  State<_ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<_ClientDialog> {
  late final name = TextEditingController(text: widget.client?.name ?? '');
  late final document = TextEditingController(text: widget.client?.document ?? '');
  late final phone = TextEditingController(text: fmtPhone(widget.client?.phone ?? ''));
  late final zip = TextEditingController(text: widget.client?.zip ?? '');
  late final address = TextEditingController(text: widget.client?.address ?? '');
  late final work = TextEditingController(text: widget.client?.workAddress ?? '');
  late bool showWork = (widget.client?.workAddress ?? '').isNotEmpty;
  String? error;

  @override
  void dispose() {
    name.dispose();
    document.dispose();
    phone.dispose();
    zip.dispose();
    address.dispose();
    work.dispose();
    super.dispose();
  }

  void save() {
    if (name.text.trim().isEmpty || digitsOnly(phone.text).length < 10) {
      setState(() => error = 'Informe o nome e um telefone com DDD.');
      return;
    }
    widget.repo.saveClient(
      id: widget.client?.id,
      name: name.text,
      document: document.text,
      phone: phone.text,
      zip: zip.text,
      address: address.text,
      workAddress: showWork ? work.text : '',
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.client == null ? 'Novo cliente' : 'Editar cliente'),
      content: SizedBox(
        width: dialogWidth(context, 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome completo')),
              const SizedBox(height: 12),
              TextField(controller: document, decoration: const InputDecoration(labelText: 'CPF / RG')),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone / WhatsApp'),
              ),
              const SizedBox(height: 12),
              TextField(controller: zip, decoration: const InputDecoration(labelText: 'CEP')),
              const SizedBox(height: 12),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Endereço')),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => showWork = !showWork),
                  child: Text(showWork ? 'Remover endereço do trabalho' : 'Endereço do trabalho'),
                ),
              ),
              if (showWork) TextField(controller: work, decoration: const InputDecoration(labelText: 'Endereço do trabalho')),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: save, child: const Text('Salvar cliente')),
      ],
    );
  }
}
