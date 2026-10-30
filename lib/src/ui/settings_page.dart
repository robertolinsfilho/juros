import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../theme.dart';
import 'messages_tab.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.repo, required this.onChanged, this.initialTab = 0});

  final Repo repo;
  final VoidCallback onChanged;
  final int initialTab;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int tab = widget.initialTab;
  late double scale = widget.repo.fontScale;

  void setScale(double value) {
    setState(() => scale = value);
    widget.repo.setSetting('font_scale', '$value');
    widget.onChanged();
  }

  Widget scaleCard() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tamanho da letra', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final item in const [(1.0, 'Normal'), (1.15, 'Grande'), (1.35, 'Muito grande')])
                ChoiceChip(
                  label: Text(item.$2),
                  selected: scale == item.$1,
                  onSelected: (_) => setScale(item.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget dataTab() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clientes, empréstimos, caixa e estas configurações ficam na conta, no servidor. O celular e o computador mostram a mesma coisa depois que você entra.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: pagePadding(context),
      children: [
        const PageHeader(
          title: 'Configurações',
          subtitle: 'Mensagens de WhatsApp, assinatura e tamanho da letra',
        ),
        const SizedBox(height: 16),
        scaleCard(),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Mensagens'), icon: Icon(Icons.chat_bubble_outline)),
            ButtonSegment(value: 1, label: Text('Dados'), icon: Icon(Icons.storage_outlined)),
          ],
          selected: {tab},
          onSelectionChanged: (value) => setState(() => tab = value.first),
          style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(AppColors.text)),
        ),
        const SizedBox(height: 16),
        if (tab == 0) MessagesTab(repo: widget.repo, onChanged: widget.onChanged) else dataTab(),
      ],
    );
  }
}
