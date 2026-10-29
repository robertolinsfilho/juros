import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../format.dart';
import 'widgets.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key, required this.repo});

  final Repo repo;

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  bool loans = true;

  @override
  Widget build(BuildContext context) {
    final loanItems = widget.repo.listLoans(deleted: true);
    final clients = widget.repo.listClients(deleted: true);
    return ListView(
      padding: pagePadding(context),
      children: [
        const PageHeader(
          title: 'Lixeira',
          subtitle: 'Empréstimos e clientes excluídos ficam aqui por 30 dias.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(label: const Text('Empréstimos'), selected: loans, onSelected: (_) => setState(() => loans = true)),
            ChoiceChip(label: const Text('Clientes'), selected: !loans, onSelected: (_) => setState(() => loans = false)),
          ],
        ),
        const SizedBox(height: 16),
        if (loans && loanItems.isEmpty)
          const Panel(child: EmptyHint(icon: Icons.delete_outline, title: 'Lixeira vazia', body: 'Nenhum empréstimo excluído.')),
        if (!loans && clients.isEmpty)
          const Panel(child: EmptyHint(icon: Icons.delete_outline, title: 'Lixeira vazia', body: 'Nenhum cliente excluído.')),
        if (loans)
          for (final loan in loanItems) ...[
            Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(loan.clientName),
                subtitle: Text('${fmtMoney(loan.principalCents)} · ${fmtDateIso(loan.contractDate)}'),
                trailing: TextButton(
                  onPressed: () {
                    widget.repo.restoreLoan(loan.id);
                    setState(() {});
                  },
                  child: const Text('Restaurar'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ]
        else
          for (final client in clients) ...[
            Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(client.name),
                subtitle: Text(fmtPhone(client.phone)),
                trailing: TextButton(
                  onPressed: () {
                    widget.repo.restoreClient(client.id);
                    setState(() {});
                  },
                  child: const Text('Restaurar'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
