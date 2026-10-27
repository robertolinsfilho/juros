import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../domain/schedule.dart';
import '../format.dart';
import '../links.dart';
import 'loan_form.dart';
import 'widgets.dart';

class LoansPage extends StatefulWidget {
  const LoansPage({super.key, required this.repo});

  final Repo repo;

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  final search = TextEditingController();
  String status = 'todos';
  String type = 'todos';
  int? selected;
  bool showNotes = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<LoanRecord> get loans => widget.repo.listLoans(query: search.text, status: status, type: type);

  Future<void> create() async {
    if (await showLoanForm(context, widget.repo) && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = selected == null ? null : widget.repo.loanById(selected!);
    if (current != null) {
      return _LoanDetail(
        repo: widget.repo,
        loan: current,
        onBack: () => setState(() => selected = null),
        onChanged: () => setState(() {}),
      );
    }
    final items = loans;
    final open = items.where((loan) => loan.displayStatus == 'Aberto').length;
    final late = items.where((loan) => loan.displayStatus == 'Atrasado').length;
    return ListView(
      padding: pagePadding(context),
      children: [
        PageHeader(
          title: 'Empréstimos',
          subtitle: '${items.length} contratos na busca',
          actions: [
            FilledButton.icon(onPressed: create, icon: const Icon(Icons.add), label: const Text('Novo empréstimo')),
          ],
        ),
        const SizedBox(height: 16),
        metricGrid([
          MetricCard(label: 'NA BUSCA', value: '${items.length}', caption: 'contratos'),
          MetricCard(label: 'ABERTOS', value: '$open', caption: 'em dia'),
          MetricCard(label: 'ATRASADOS', value: '$late', caption: 'com parcela vencida'),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Buscar por cliente', prefixIcon: Icon(Icons.search)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              ('todos', 'Todos'),
              ('aberto', 'Em aberto'),
              ('atrasado', 'Atrasados'),
              ('quitado', 'Quitados'),
              ('perdido', 'Perdidos'),
            ])
              ChoiceChip(
                label: Text(item.$2),
                selected: status == item.$1,
                onSelected: (_) => setState(() => status = item.$1),
              ),
            ChoiceChip(
              label: const Text('Mostrar observações'),
              selected: showNotes,
              onSelected: (value) => setState(() => showNotes = value),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: const [
            DropdownMenuItem(value: 'todos', child: Text('Todos os tipos')),
            DropdownMenuItem(value: 'apenas_juros', child: Text('Juros + capital no final')),
            DropdownMenuItem(value: 'diario', child: Text('Diário')),
            DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
            DropdownMenuItem(value: 'dez_dias', child: Text('A cada 10 dias')),
            DropdownMenuItem(value: 'quinzenal', child: Text('Quinzenal')),
            DropdownMenuItem(value: 'mensal', child: Text('Mensal')),
            DropdownMenuItem(value: 'n_dias', child: Text('A cada N dias')),
          ],
          onChanged: (value) => setState(() => type = value ?? 'todos'),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Panel(child: EmptyHint(icon: Icons.receipt_long, title: 'Nenhum empréstimo', body: 'Crie o primeiro contrato para gerar as parcelas.'))
        else
          for (final loan in items) ...[
            Panel(
              padding: EdgeInsets.zero,
              child: RecordTile(
                onTap: () => setState(() => selected = loan.id),
                title: loan.clientName,
                subtitle: '${loan.typeLabel}\n${fmtMoney(loan.principalCents)} · ${fmtRate(loan.rateBps)} · ${loan.count} parcelas'
                    '${showNotes && loan.notes.isNotEmpty ? '\n${loan.notes}' : ''}',
                actions: [
                  StatusPill(label: loan.displayStatus),
                  Text(loan.nextDue == null ? fmtMoney(loan.openCents) : '${fmtDateIso(loan.nextDue!)} · ${fmtMoney(loan.openCents)}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _LoanDetail extends StatelessWidget {
  const _LoanDetail({
    required this.repo,
    required this.loan,
    required this.onBack,
    required this.onChanged,
  });

  final Repo repo;
  final LoanRecord loan;
  final VoidCallback onBack;
  final VoidCallback onChanged;

  Future<void> receive(BuildContext context, InstallmentRecord item) async {
    final late = item.liveLateCents(DateTime.now());
    final ok = await confirmAction(
      context,
      'Registrar recebimento',
      'Confirmar ${fmtMoney(item.faceCents + late)} de ${item.clientName}?',
    );
    if (!ok) return;
    repo.payInstallment(item.id);
    onChanged();
  }

  Future<void> charge(BuildContext context, InstallmentRecord item) async {
    final late = item.liveLateCents(DateTime.now());
    final opened = await openWhatsApp(
      phone: item.clientPhone,
      message: chargeMessage(
        client: item.clientName,
        number: item.number,
        count: item.count,
        cents: item.faceCents + late,
        dueIso: item.dueDate,
        creditor: repo.setting('creditor_name'),
        pix: repo.setting('pix_key'),
        lateCents: late,
      ),
    );
    if (!opened && context.mounted) showError(context, 'Não foi possível abrir o WhatsApp.');
  }

  Future<void> lose(BuildContext context) async {
    final ok = await confirmAction(context, 'Marcar como perdido', 'As parcelas em aberto saem da carteira.');
    if (!ok) return;
    repo.markLost(loan.id);
    onChanged();
  }

  Future<void> remove(BuildContext context) async {
    final ok = await confirmAction(context, 'Mover para a lixeira', 'O contrato fica 30 dias na lixeira.');
    if (!ok) return;
    repo.deleteLoan(loan.id);
    onBack();
  }

  @override
  Widget build(BuildContext context) {
    final items = repo.installmentsOf(loan.id);
    final mode = RateModeLabel.parse(loan.rateMode).label;
    return ListView(
      padding: pagePadding(context),
      children: [
        PageHeader(
          title: loan.clientName,
          subtitle: '${loan.typeLabel} · $mode · ${fmtRate(loan.rateBps)}',
          actions: [
            OutlinedButton(onPressed: onBack, child: const Text('Voltar')),
            if (loan.status == 'aberto') OutlinedButton(onPressed: () => lose(context), child: const Text('Marcar perdido')),
            OutlinedButton(onPressed: () => remove(context), child: const Text('Excluir')),
          ],
        ),
        const SizedBox(height: 16),
        metricGrid([
          MetricCard(label: 'EMPRESTADO', value: fmtMoney(loan.principalCents), caption: fmtDateIso(loan.contractDate)),
          MetricCard(label: 'EM ABERTO', value: fmtMoney(loan.openCents), caption: '${loan.count} parcelas'),
          MetricCard(label: 'STATUS', value: loan.displayStatus, caption: loan.notes.isEmpty ? 'sem observação' : loan.notes),
        ]),
        const SizedBox(height: 12),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final item in items)
                RecordTile(
                  title: 'Parcela ${item.number}/${item.count} · ${fmtDateIso(item.dueDate)}',
                  subtitle: 'Capital ${fmtMoney(item.principalCents)} · juros ${fmtMoney(item.interestCents)}'
                      '${item.isOpen && item.liveLateCents(DateTime.now()) > 0 ? ' · mora ${fmtMoney(item.liveLateCents(DateTime.now()))}' : ''}'
                      '${item.paidAt != null ? ' · pago em ${fmtDateIso(item.paidAt!)}' : ''}',
                  actions: [
                    if (item.isOpen) ...[
                      TextButton(onPressed: () => charge(context, item), child: const Text('Cobrar')),
                      FilledButton(onPressed: () => receive(context, item), child: const Text('Receber')),
                    ] else
                      StatusPill(label: item.status == 'paga' ? 'Pago' : 'Perdido'),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
