import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../domain/schedule.dart';
import '../format.dart';
import 'client_form.dart';
import 'widgets.dart';

Future<bool> showLoanForm(BuildContext context, Repo repo) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _LoanDialog(repo: repo),
  ).then((value) => value ?? false);
}

class _LoanDialog extends StatefulWidget {
  const _LoanDialog({required this.repo});

  final Repo repo;

  @override
  State<_LoanDialog> createState() => _LoanDialogState();
}

class _LoanDialogState extends State<_LoanDialog> {
  late List<ClientRecord> clients = widget.repo.listClients();
  int? clientId;
  final principal = TextEditingController();
  final rate = TextEditingController();
  final count = TextEditingController(text: '1');
  final interval = TextEditingController(text: '20');
  final latePercent = TextEditingController(text: '0');
  final lateDaily = TextEditingController();
  final lateFixed = TextEditingController();
  final notes = TextEditingController();
  ContractMode contractMode = ContractMode.amortizacao;
  RateMode rateMode = RateMode.porParcela;
  Frequency frequency = Frequency.mensal;
  String lateMode = 'sem_mora';
  DateTime contractDate = DateTime.now();
  bool skipSaturday = false;
  bool skipSunday = false;
  bool skipHoliday = false;
  String? error;

  @override
  void dispose() {
    principal.dispose();
    rate.dispose();
    count.dispose();
    interval.dispose();
    latePercent.dispose();
    lateDaily.dispose();
    lateFixed.dispose();
    notes.dispose();
    super.dispose();
  }

  LoanDraft? draft() {
    final value = parseMoney(principal.text);
    final rateBps = parsePercentBps(rate.text);
    final installments = int.tryParse(count.text.trim());
    final every = int.tryParse(interval.text.trim()) ?? 1;
    if (clientId == null || value == null || value <= 0 || rateBps == null || installments == null || installments < 1) {
      return null;
    }
    return LoanDraft(
      clientId: clientId!,
      principalCents: value,
      rateBps: rateBps,
      rateMode: rateMode,
      contractMode: contractMode,
      frequency: frequency,
      intervalDays: every,
      count: installments,
      contractDate: contractDate,
      skipSaturday: skipSaturday,
      skipSunday: skipSunday,
      skipHoliday: skipHoliday,
      lateMode: lateMode,
      latePercentBps: parsePercentBps(latePercent.text) ?? 0,
      lateDailyCents: parseMoney(lateDaily.text) ?? 0,
      lateFixedCents: parseMoney(lateFixed.text) ?? 0,
      notes: notes.text,
    );
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: contractDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => contractDate = picked);
  }

  Future<void> addClient() async {
    final saved = await showClientForm(context, widget.repo);
    if (!saved || !mounted) return;
    setState(() {
      clients = widget.repo.listClients();
      if (clients.isNotEmpty) clientId = clients.last.id;
    });
  }

  void save() {
    final current = draft();
    if (current == null) {
      setState(() => error = 'Escolha o cliente e informe valor, taxa e parcelas.');
      return;
    }
    widget.repo.createLoan(current);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final current = draft();
    final plan = current == null ? const <PlannedInstallment>[] : buildSchedule(current);
    final interest = plan.fold<int>(0, (sum, item) => sum + item.interestCents);
    final total = plan.fold<int>(0, (sum, item) => sum + item.totalCents);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Novo empréstimo'),
      content: SizedBox(
        width: dialogWidth(context, 640),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldPair(
                left: DropdownButtonFormField<int>(
                  initialValue: clientId,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                  items: [
                    for (final client in clients)
                      DropdownMenuItem(value: client.id, child: Text(client.name)),
                  ],
                  onChanged: (value) => setState(() => clientId = value),
                ),
                right: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(onPressed: addClient, child: const Text('Novo')),
                ),
              ),
              const SizedBox(height: 12),
              FieldPair(
                left: TextField(controller: principal, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Valor'), keyboardType: TextInputType.number),
                right: TextField(controller: rate, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Taxa de juros (%)'), keyboardType: TextInputType.number),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ContractMode>(
                initialValue: contractMode,
                decoration: const InputDecoration(labelText: 'Modo do contrato'),
                items: [
                  for (final mode in ContractMode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.label)),
                ],
                onChanged: (value) => setState(() => contractMode = value ?? contractMode),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RateMode>(
                initialValue: rateMode,
                decoration: const InputDecoration(labelText: 'Juros aplicado'),
                items: [
                  for (final mode in RateMode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.label)),
                ],
                onChanged: (value) => setState(() => rateMode = value ?? rateMode),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Frequency>(
                initialValue: frequency,
                decoration: const InputDecoration(labelText: 'Frequência'),
                items: [
                  for (final item in Frequency.values)
                    DropdownMenuItem(value: item, child: Text(item.label)),
                ],
                onChanged: (value) => setState(() => frequency = value ?? frequency),
              ),
              if (frequency == Frequency.nDias) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: interval,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Intervalo em dias'),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: count,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Número de parcelas'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: pickDate, child: Text('Data do contrato: ${fmtDate(contractDate)}')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(label: const Text('Pular sábado'), selected: skipSaturday, onSelected: (value) => setState(() => skipSaturday = value)),
                  FilterChip(label: const Text('Pular domingo'), selected: skipSunday, onSelected: (value) => setState(() => skipSunday = value)),
                  FilterChip(label: const Text('Pular feriado'), selected: skipHoliday, onSelected: (value) => setState(() => skipHoliday = value)),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: lateMode,
                decoration: const InputDecoration(labelText: 'Juros por atraso (mora)'),
                items: const [
                  DropdownMenuItem(value: 'sem_mora', child: Text('Sem mora')),
                  DropdownMenuItem(value: 'percentual_dia', child: Text('% ao dia')),
                  DropdownMenuItem(value: 'valor_fixo', child: Text('Valor fixo por dia')),
                  DropdownMenuItem(value: 'taxa_unica_percentual', child: Text('Taxa única + % ao dia')),
                ],
                onChanged: (value) => setState(() => lateMode = value ?? lateMode),
              ),
              if (lateMode == 'percentual_dia' || lateMode == 'taxa_unica_percentual') ...[
                const SizedBox(height: 12),
                TextField(controller: latePercent, decoration: const InputDecoration(labelText: 'Percentual ao dia'), keyboardType: TextInputType.number),
              ],
              if (lateMode == 'valor_fixo') ...[
                const SizedBox(height: 12),
                TextField(controller: lateDaily, decoration: const InputDecoration(labelText: 'Valor por dia'), keyboardType: TextInputType.number),
              ],
              if (lateMode == 'taxa_unica_percentual') ...[
                const SizedBox(height: 12),
                TextField(controller: lateFixed, decoration: const InputDecoration(labelText: 'Taxa única'), keyboardType: TextInputType.number),
              ],
              const SizedBox(height: 12),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Observações'), maxLines: 2),
              const SizedBox(height: 16),
              if (plan.isNotEmpty)
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Juros: ${fmtMoney(interest)}'),
                      Text('Primeira parcela: ${fmtMoney(plan.first.totalCents)} em ${fmtDate(plan.first.due)}'),
                      Text('Total a receber: ${fmtMoney(total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
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
        FilledButton(onPressed: save, child: const Text('Criar empréstimo')),
      ],
    );
  }
}
