import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repository.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.repo, required this.onChanged});

  final Repo repo;
  final VoidCallback onChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final creditor = TextEditingController(text: widget.repo.setting('creditor_name'));
  late final pix = TextEditingController(text: widget.repo.setting('pix_key'));
  late double scale = widget.repo.fontScale;

  @override
  void dispose() {
    creditor.dispose();
    pix.dispose();
    super.dispose();
  }

  void save() {
    widget.repo.setSetting('creditor_name', creditor.text.trim());
    widget.repo.setSetting('pix_key', pix.text.trim());
    widget.repo.setSetting('font_scale', '$scale');
    widget.onChanged();
    showError(context, 'Configurações salvas.');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PageHeader(
          title: 'Configurações',
          subtitle: 'Nome, PIX e tamanho da letra neste computador',
        ),
        const SizedBox(height: 16),
        TextField(controller: creditor, decoration: const InputDecoration(labelText: 'Seu nome nas cobranças')),
        const SizedBox(height: 12),
        TextField(controller: pix, decoration: const InputDecoration(labelText: 'Chave PIX')),
        const SizedBox(height: 16),
        const Text('Tamanho da letra'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final item in const [(1.0, 'Normal'), (1.15, 'Grande'), (1.35, 'Muito grande')])
              ChoiceChip(
                label: Text(item.$2),
                selected: scale == item.$1,
                onSelected: (_) => setState(() => scale = item.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: save, child: const Text('Salvar')),
        const SizedBox(height: 24),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Os dados ficam só neste computador.'),
              const SizedBox(height: 8),
              SelectableText(widget.repo.dbPath),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.repo.dbPath));
                  showError(context, 'Caminho copiado.');
                },
                child: const Text('Copiar caminho'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
