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
  final parcelValue = TextEditingController();
  final jurosTotal = TextEditingController();
  final latePercent = TextEditingController(text: '0');
  final lateDaily = TextEditingController();
  final lateFixed = TextEditingController();
  final notes = TextEditingController();
  final rowAmounts = <int, TextEditingController>{};
  ContractMode contractMode = ContractMode.amortizacao;
  RateMode rateMode = RateMode.porParcela;
  Frequency frequency = Frequency.mensal;
  Frequency chargeFrequency = Frequency.mensal;
  String lateMode = 'sem_mora';
  DateTime contractDate = DateTime.now();
  late DateTime firstCharge = addMonths(DateTime.now(), 1);
  bool firstChargeTouched = false;
  bool skipSaturday = false;
  bool skipSunday = false;
  bool skipHoliday = false;
  bool moreDays = false;
  int skipWeekdays = 0;
  bool fixedInstallment = false;
  final dueOverrides = <int, DateTime>{};
  final amountOverrides = <int, int>{};
  String? error;

  bool get interestPlusCapital => contractMode == ContractMode.apenasJuros;
  bool get customSchedule => !interestPlusCapital && frequency == Frequency.personalizado;

  Frequency get spacing {
    if (interestPlusCapital) return frequency;
    if (customSchedule) return chargeFrequency;
    return frequency;
  }

  bool get asksInterval => spacing == Frequency.nDias;

  @override
  void dispose() {
    principal.dispose();
    rate.dispose();
    count.dispose();
    interval.dispose();
    parcelValue.dispose();
    jurosTotal.dispose();
    latePercent.dispose();
    lateDaily.dispose();
    lateFixed.dispose();
    notes.dispose();
    for (final controller in rowAmounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  LoanDraft? draft() {
    final value = parseMoney(principal.text);
    final rateBps = parsePercentBps(rate.text);
    final installments = interestPlusCapital ? 1 : int.tryParse(count.text.trim());
    final every = int.tryParse(interval.text.trim()) ?? 0;
    if (clientId == null || value == null || value <= 0 || rateBps == null || installments == null || installments < 1) {
      return null;
    }
    if (asksInterval && (every < 2 || every > 60)) return null;
    return LoanDraft(
      clientId: clientId!,
      principalCents: value,
      rateBps: rateBps,
      rateMode: interestPlusCapital || customSchedule ? RateMode.total : rateMode,
      contractMode: contractMode,
      frequency: interestPlusCapital ? frequency : frequency,
      intervalDays: every < 1 ? 1 : every,
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
      skipWeekdays: skipWeekdays,
      fixedInstallment: interestPlusCapital && fixedInstallment,
      openInterest: interestPlusCapital,
      firstDue: interestPlusCapital ? firstCharge : null,
      chargeFrequency: customSchedule ? chargeFrequency : null,
      dueOverrides: dueOverrides,
      amountOverrides: amountOverrides,
    );
  }

  void applyParcelValue(String raw) {
    final payment = parseMoney(raw);
    final value = parseMoney(principal.text);
    final installments = int.tryParse(count.text.trim());
    if (payment == null || value == null || value <= 0 || installments == null || installments < 1) return;
    final interest = payment * installments - value;
    if (interest < 0) return;
    final percent = rateMode == RateMode.total ? interest / value * 100 : interest / value / installments * 100;
    rate.text = percent.toStringAsFixed(2).replaceAll('.', ',');
    setState(() => error = null);
  }

  void applyInterestTotal(String raw) {
    final interest = parseMoney(raw);
    final value = parseMoney(principal.text);
    if (interest == null || value == null || value <= 0) return;
    rateMode = RateMode.total;
    rate.text = (interest / value * 100).toStringAsFixed(2).replaceAll('.', ',');
    amountOverrides.clear();
    setState(() => error = null);
  }

  Future<void> pickDate({required bool first}) async {
    final initial = first ? firstCharge : contractDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (first) {
        firstCharge = picked;
        firstChargeTouched = true;
      } else {
        contractDate = picked;
        if (!firstChargeTouched) firstCharge = addMonths(picked, 1);
      }
    });
  }

  Future<void> pickDue(int number, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => dueOverrides[number] = picked);
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
      setState(() => error = asksInterval
          ? 'Escolha o cliente e use um intervalo de 2 a 60 dias.'
          : interestPlusCapital
          ? 'Escolha o cliente e informe valor e taxa.'
          : 'Escolha o cliente e informe valor, taxa e parcelas.');
      return;
    }
    widget.repo.createLoan(current);
    Navigator.pop(context, true);
  }

  TextEditingController rowController(PlannedInstallment item) {
    return rowAmounts.putIfAbsent(item.number, () {
      final cents = amountOverrides[item.number] ?? item.totalCents;
      return TextEditingController(text: (cents / 100).toStringAsFixed(2).replaceAll('.', ','));
    });
  }

  void toggleWeekday(int bit, bool selected) {
    setState(() {
      skipWeekdays = selected ? skipWeekdays | bit : skipWeekdays & ~bit;
    });
  }

  String frequencyText(Frequency item) {
    if (!interestPlusCapital && item == Frequency.mensal) return 'Parcelado (Mensal)';
    if (interestPlusCapital && item == Frequency.diario) return 'Diária (1 dia)';
    return item.label;
  }

  @override
  Widget build(BuildContext context) {
    final current = draft();
    final plan = current == null ? const <PlannedInstallment>[] : buildSchedule(current);
    final interest = plan.fold<int>(0, (sum, item) => sum + item.interestCents);
    final total = plan.fold<int>(0, (sum, item) => sum + item.totalCents);
    final value = parseMoney(principal.text) ?? 0;
    final parcelCents = plan.isEmpty ? 0 : plan.first.totalCents;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Novo empréstimo'),
      content: SizedBox(
        width: dialogWidth(context, 680),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                initialValue: clientId,
                decoration: const InputDecoration(labelText: 'Cliente *'),
                items: [
                  for (final client in clients) DropdownMenuItem(value: client.id, child: Text(client.name)),
                ],
                onChanged: (next) => setState(() => clientId = next),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: addClient, child: const Text('Cadastrar novo cliente')),
              const SizedBox(height: 12),
              FieldPair(
                left: TextField(
                  controller: principal,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Valor *'),
                  keyboardType: TextInputType.number,
                ),
                right: TextField(
                  controller: rate,
                  onChanged: (_) {
                    parcelValue.clear();
                    setState(() {});
                  },
                  decoration: const InputDecoration(labelText: 'Taxa de juros (%) *'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ContractMode>(
                key: ValueKey(contractMode),
                initialValue: contractMode,
                decoration: const InputDecoration(labelText: 'Modo do contrato'),
                items: [
                  for (final mode in ContractMode.values) DropdownMenuItem(value: mode, child: Text(mode.label)),
                ],
                onChanged: (next) => setState(() {
                  contractMode = next ?? contractMode;
                  if (interestPlusCapital && frequency == Frequency.personalizado) frequency = Frequency.mensal;
                }),
              ),
              const SizedBox(height: 12),
              if (!interestPlusCapital && !customSchedule) ...[
                DropdownButtonFormField<RateMode>(
                  key: ValueKey(rateMode),
                  initialValue: rateMode,
                  decoration: const InputDecoration(labelText: 'Juros aplicado'),
                  items: [
                    for (final mode in RateMode.values) DropdownMenuItem(value: mode, child: Text(mode.label)),
                  ],
                  onChanged: (next) => setState(() => rateMode = next ?? rateMode),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<Frequency>(
                key: ValueKey('freq-${interestPlusCapital ? 'juros' : 'parcelado'}-$frequency'),
                initialValue: frequency,
                decoration: InputDecoration(labelText: interestPlusCapital ? 'Frequência de cobrança' : 'Frequência'),
                items: [
                  for (final item in Frequency.values)
                    if (interestPlusCapital ? item != Frequency.personalizado : true)
                      DropdownMenuItem(value: item, child: Text(frequencyText(item))),
                ],
                onChanged: (next) => setState(() => frequency = next ?? frequency),
              ),
              if (customSchedule) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<Frequency>(
                  key: ValueKey(chargeFrequency),
                  initialValue: chargeFrequency == Frequency.personalizado ? Frequency.mensal : chargeFrequency,
                  decoration: const InputDecoration(labelText: 'Frequência de cobrança'),
                  items: [
                    for (final item in Frequency.values)
                      if (item != Frequency.personalizado && item != Frequency.diario)
                        DropdownMenuItem(value: item, child: Text(item == Frequency.mensal ? 'Mensal' : item.label)),
                  ],
                  onChanged: (next) => setState(() => chargeFrequency = next ?? chargeFrequency),
                ),
              ],
              if (asksInterval) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: interval,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'A cada quantos dias? *'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 4),
                const Text('Use de 2 a 60 dias. Para 1 dia, escolha diária; acima de 60, mensal.', style: TextStyle(fontSize: 12)),
              ],
              if (!interestPlusCapital) ...[
                const SizedBox(height: 12),
                FieldPair(
                  left: TextField(
                    controller: count,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Nº de parcelas *'),
                    keyboardType: TextInputType.number,
                  ),
                  right: customSchedule
                      ? TextField(
                          controller: jurosTotal,
                          onChanged: applyInterestTotal,
                          decoration: const InputDecoration(labelText: 'Juros total (R\$)'),
                          keyboardType: TextInputType.number,
                        )
                      : InputDecorator(
                          decoration: const InputDecoration(labelText: 'Juros total (R\$)'),
                          child: Text(plan.isEmpty ? '' : fmtMoney(interest)),
                        ),
                ),
                const SizedBox(height: 12),
                if (!customSchedule)
                  FieldPair(
                    left: TextField(
                      controller: parcelValue,
                      onChanged: applyParcelValue,
                      decoration: InputDecoration(
                        labelText: 'Valor da parcela (R\$)',
                        hintText: parcelCents > 0 ? fmtMoney(parcelCents) : '0,00',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    right: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Total a receber'),
                      child: Text(plan.isEmpty ? '' : fmtMoney(total), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Total a receber'),
                    child: Text(plan.isEmpty ? '' : fmtMoney(total), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
              if (interestPlusCapital) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: parcelValue,
                  onChanged: (raw) {
                    final payment = parseMoney(raw);
                    final lent = parseMoney(principal.text);
                    if (payment == null || lent == null || lent <= 0) return;
                    rate.text = (payment / lent * 100).toStringAsFixed(2).replaceAll('.', ',');
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: 'Valor da parcela (R\$)',
                    hintText: parcelCents > 0 ? fmtMoney(parcelCents) : '0,00',
                    helperText: 'Preencha a taxa ou o valor da parcela. O outro é calculado.',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => pickDate(first: true),
                  child: Text('Data da primeira cobrança: ${fmtDate(firstCharge)}'),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Data da primeira cobrança de juros', style: TextStyle(fontSize: 12)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Parcela fixa até quitar'),
                  subtitle: const Text('O valor da parcela não muda mesmo com pagamentos a mais'),
                  value: fixedInstallment,
                  onChanged: (next) => setState(() => fixedInstallment = next),
                ),
              ],
              if (value > 0 && total > 0 && total < value)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Você vai receber ${fmtMoney(value - total)} a menos do que está emprestando.',
                    style: const TextStyle(color: Colors.amber),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => pickDate(first: false), child: Text('Data do contrato: ${fmtDate(contractDate)}')),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Quando foi fechado', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 12),
              const Text('Não cobra nos seguintes dias:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(label: const Text('Sábado'), selected: skipSaturday, onSelected: (next) => setState(() => skipSaturday = next)),
                  FilterChip(label: const Text('Domingo'), selected: skipSunday, onSelected: (next) => setState(() => skipSunday = next)),
                  FilterChip(label: const Text('Feriados'), selected: skipHoliday, onSelected: (next) => setState(() => skipHoliday = next)),
                  ActionChip(label: const Text('Mais dias'), onPressed: () => setState(() => moreDays = !moreDays)),
                ],
              ),
              if (moreDays) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final day in const [(1, 'Segunda'), (2, 'Terça'), (4, 'Quarta'), (8, 'Quinta'), (16, 'Sexta')])
                      FilterChip(
                        label: Text(day.$2),
                        selected: (skipWeekdays & day.$1) != 0,
                        onSelected: (next) => toggleWeekday(day.$1, next),
                      ),
                  ],
                ),
              ],
              if (!interestPlusCapital && plan.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(customSchedule ? 'Parcelas — valor e vencimento' : 'Vencimento das parcelas'),
                const SizedBox(height: 8),
                for (final item in plan) ...[
                  Row(
                    children: [
                      SizedBox(width: 88, child: Text('Parcela ${item.number}')),
                      Expanded(
                        child: customSchedule
                            ? TextField(
                                controller: rowController(item),
                                onChanged: (raw) {
                                  final cents = parseMoney(raw);
                                  setState(() {
                                    if (cents == null) {
                                      amountOverrides.remove(item.number);
                                    } else {
                                      amountOverrides[item.number] = cents;
                                    }
                                  });
                                },
                                decoration: const InputDecoration(isDense: true, labelText: 'Valor'),
                                keyboardType: TextInputType.number,
                              )
                            : Text(fmtMoney(item.totalCents)),
                      ),
                      TextButton(
                        onPressed: () => pickDue(item.number, item.due),
                        child: Text(fmtDate(item.due)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(lateMode),
                initialValue: lateMode,
                decoration: const InputDecoration(labelText: 'Juros por atraso (mora)'),
                items: const [
                  DropdownMenuItem(value: 'sem_mora', child: Text('Sem mora')),
                  DropdownMenuItem(value: 'percentual_dia', child: Text('% ao dia')),
                  DropdownMenuItem(value: 'valor_fixo', child: Text('Valor fixo por dia')),
                  DropdownMenuItem(value: 'taxa_unica_percentual', child: Text('Taxa única + % ao dia')),
                ],
                onChanged: (next) => setState(() => lateMode = next ?? lateMode),
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
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Observações (opcional)', hintText: 'Ex: Empréstimo para reforma da casa'),
                maxLines: 2,
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
        FilledButton(onPressed: save, child: const Text('Confirmar e criar empréstimo')),
      ],
    );
  }
}
