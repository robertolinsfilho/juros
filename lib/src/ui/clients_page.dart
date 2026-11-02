import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../format.dart';
import '../links.dart';
import 'client_form.dart';
import 'loan_form.dart';
import 'loans_page.dart';
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
  int? openedId;
  int? openedLoanId;
  String loanFilter = 'aberto';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() => setState(() => clients = widget.repo.listClients(query: search.text));

  Future<void> create() async {
    if (await showClientForm(context, widget.repo) != null && mounted) reload();
  }

  Future<void> edit(ClientRecord client) async {
    if (await showClientForm(context, widget.repo, client: client) != null && mounted) reload();
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

  ClientRecord? _openedClient() {
    final id = openedId;
    if (id == null) return null;
    for (final client in widget.repo.listClients()) {
      if (client.id == id) return client;
    }
    return null;
  }

  Future<void> createLoan(ClientRecord client) async {
    if (await showLoanForm(context, widget.repo, clientId: client.id) && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final opened = _openedClient();
    if (opened != null) {
      final loan = openedLoanId == null ? null : widget.repo.loanById(openedLoanId!);
      if (loan != null && loan.clientId == opened.id) {
        return LoanDetail(
          repo: widget.repo,
          loan: loan,
          onBack: () => setState(() => openedLoanId = null),
          onChanged: () => setState(() {}),
        );
      }
      return _ClientLoans(
        repo: widget.repo,
        client: opened,
        filter: loanFilter,
        onFilter: (value) => setState(() => loanFilter = value),
        onBack: () => setState(() {
          openedId = null;
          openedLoanId = null;
          loanFilter = 'aberto';
        }),
        onOpenLoan: (id) => setState(() => openedLoanId = id),
        onEdit: () => edit(opened),
        onCreate: () => createLoan(opened),
        onChat: () => chat(opened),
      );
    }
    final overdue = clients.where((client) => client.overdueCount > 0).length;
    final today = clients.where((client) => client.dueToday > 0).length;
    return ListView(
      padding: pagePadding(context),
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
        const SizedBox(height: 16),
        if (clients.isEmpty)
          const Panel(child: EmptyHint(icon: Icons.people_outline, title: 'Nenhum cliente', body: 'Cadastre a primeira pessoa para lançar um empréstimo.'))
        else
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final client in clients)
                  RecordTile(
                    onTap: () => setState(() {
                      openedId = client.id;
                      loanFilter = 'aberto';
                    }),
                    title: client.name,
                    subtitle: '${client.document.isEmpty ? 'Sem documento' : client.document} · ${fmtPhone(client.phone)}',
                    actions: [
                      StatusPill(label: client.statusLabel),
                      IconButton(tooltip: 'WhatsApp', onPressed: () => chat(client), icon: const Icon(Icons.chat_outlined)),
                      IconButton(tooltip: 'Editar', onPressed: () => edit(client), icon: const Icon(Icons.edit_outlined)),
                      IconButton(tooltip: 'Excluir', onPressed: () => remove(client), icon: const Icon(Icons.delete_outline)),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ClientLoans extends StatelessWidget {
  const _ClientLoans({
    required this.repo,
    required this.client,
    required this.filter,
    required this.onFilter,
    required this.onBack,
    required this.onOpenLoan,
    required this.onEdit,
    required this.onCreate,
    required this.onChat,
  });

  final Repo repo;
  final ClientRecord client;
  final String filter;
  final ValueChanged<String> onFilter;
  final VoidCallback onBack;
  final ValueChanged<int> onOpenLoan;
  final VoidCallback onEdit;
  final VoidCallback onCreate;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final loans = repo.listLoans().where((loan) => loan.clientId == client.id).toList();
    final open = loans.where((loan) => loan.status == 'aberto').toList();
    final late = open.where((loan) => loan.displayStatus == 'Atrasado').toList();
    final shown = switch (filter) {
      'atrasado' => late,
      'quitado' => loans.where((loan) => loan.displayStatus == 'Quitado').toList(),
      _ => open,
    };
    final openValue = open.fold<int>(0, (sum, loan) => sum + loan.openCents);
    final contact = [
      if (client.document.isNotEmpty) client.document,
      fmtPhone(client.phone),
    ].join(' · ');
    return ListView(
      padding: pagePadding(context),
      children: [
        PageHeader(
          title: client.name,
          subtitle: contact,
          actions: [
            OutlinedButton(onPressed: onBack, child: const Text('Voltar')),
            OutlinedButton(onPressed: onChat, child: const Text('WhatsApp')),
            OutlinedButton(onPressed: onEdit, child: const Text('Editar')),
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Novo empréstimo')),
          ],
        ),
        const SizedBox(height: 16),
        metricGrid([
          MetricCard(label: 'EM ABERTO', value: '${open.length}', caption: 'contratos que ainda não quitou'),
          MetricCard(label: 'ATRASADOS', value: '${late.length}', caption: 'com parcela vencida'),
          MetricCard(label: 'A RECEBER', value: fmtMoney(openValue), caption: 'soma do que falta'),
        ]),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [('aberto', 'Em aberto'), ('atrasado', 'Atrasados'), ('quitado', 'Quitados')])
              ChoiceChip(
                label: Text(item.$2),
                selected: filter == item.$1,
                onSelected: (_) => onFilter(item.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (shown.isEmpty)
          Panel(
            child: EmptyHint(
              icon: Icons.receipt_long,
              title: filter == 'aberto' ? 'Nenhum empréstimo em aberto' : 'Nenhum contrato nesta lista',
              body: filter == 'aberto' ? 'Os contratos quitados ficam na outra lista.' : 'Troque o filtro para ver os outros contratos.',
            ),
          )
        else
          for (final loan in shown) ...[
            Panel(
              padding: EdgeInsets.zero,
              child: RecordTile(
                onTap: () => onOpenLoan(loan.id),
                title: loan.typeLabel,
                subtitle: '${fmtMoney(loan.principalCents)} · ${fmtDateIso(loan.contractDate)}'
                    '${loan.nextDue == null ? '' : '\nPróximo vencimento ${fmtDateIso(loan.nextDue!)}'}',
                actions: [
                  StatusPill(label: loan.displayStatus),
                  Text(fmtMoney(loan.openCents)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
