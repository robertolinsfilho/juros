import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../format.dart';
import '../links.dart';
import 'client_form.dart';
import 'widgets.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key, required this.repo});

  final Repo repo;

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final search = TextEditingController();
  late List<ClientRecord> clients = widget.repo.listClients();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() => setState(() => clients = widget.repo.listClients(query: search.text));

  Future<void> create() async {
    if (await showClientForm(context, widget.repo) && mounted) reload();
  }

  Future<void> edit(ClientRecord client) async {
    if (await showClientForm(context, widget.repo, client: client) && mounted) reload();
  }

  Future<void> remove(ClientRecord client) async {
    final ok = await confirmAction(context, 'Mover para a lixeira', '${client.name} fica 30 dias na lixeira.');
    if (!ok || !mounted) return;
    final error = widget.repo.deleteClient(client.id);
    if (error != null) {
      showError(context, error);
      return;
    }
    reload();
  }

  Future<void> chat(ClientRecord client) async {
    final opened = await openWhatsApp(phone: client.phone, message: 'Olá ${client.name}.');
    if (!opened && mounted) showError(context, 'Não foi possível abrir o WhatsApp.');
  }

  @override
  Widget build(BuildContext context) {
    final overdue = clients.where((client) => client.overdueCount > 0).length;
    final today = clients.where((client) => client.dueToday > 0).length;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeader(
          title: 'Clientes',
          subtitle: 'Contatos e situação de cada pessoa',
          actions: [
            FilledButton.icon(onPressed: create, icon: const Icon(Icons.person_add_alt), label: const Text('Novo cliente')),
          ],
        ),
        const SizedBox(height: 16),
        metricGrid([
          MetricCard(label: 'TOTAL', value: '${clients.length}', caption: 'na busca atual'),
          MetricCard(label: 'EM ATRASO', value: '$overdue', caption: 'com parcela vencida'),
          MetricCard(label: 'COBRANÇA HOJE', value: '$today', caption: 'vencem hoje'),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: search,
          onChanged: (_) => reload(),
          decoration: const InputDecoration(
            hintText: 'Buscar por nome, CPF ou telefone',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        if (clients.isEmpty)
          const Panel(child: EmptyHint(icon: Icons.people_outline, title: 'Nenhum cliente', body: 'Cadastre a primeira pessoa para lançar um empréstimo.'))
        else
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final client in clients)
                  ListTile(
                    title: Text(client.name),
                    subtitle: Text('${client.document.isEmpty ? 'Sem documento' : client.document} · ${fmtPhone(client.phone)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusPill(label: client.statusLabel),
                        IconButton(tooltip: 'WhatsApp', onPressed: () => chat(client), icon: const Icon(Icons.chat_outlined)),
                        IconButton(tooltip: 'Editar', onPressed: () => edit(client), icon: const Icon(Icons.edit_outlined)),
                        IconButton(tooltip: 'Excluir', onPressed: () => remove(client), icon: const Icon(Icons.delete_outline)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
