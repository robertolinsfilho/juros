import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../domain/schedule.dart';
import '../format.dart';
import 'late_fee_fields.dart';
import 'widgets.dart';

Future<bool> showLoanEdit(BuildContext context, Repo repo, LoanRecord loan) async {
  final draft = repo.draftOf(loan.id);
  if (draft == null) return false;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _LoanEditDialog(
      repo: repo,
      loan: loan,
      original: draft,
      hasPayments: repo.loanHasPayments(loan.id),
    ),
  );
  return result ?? false;
}

String _moneyText(int cents) => cents == 0 ? '' : (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

String _percentText(int bps) => bps == 0 ? '' : (bps / 100).toStringAsFixed(2).replaceAll('.', ',');

class _LoanEditDialog extends StatefulWidget {
  const _LoanEditDialog({
    required this.repo,
    required this.loan,
    required this.original,
    required this.hasPayments,
  });

  final Repo repo;
  final LoanRecord loan;
  final LoanDraft original;
  final bool hasPayments;

  @override
  State<_LoanEditDialog> createState() => _LoanEditDialogState();
}

class _LoanEditDialogState extends State<_LoanEditDialog> {
  late final LoanDraft base = widget.original;
  late final principal = TextEditingController(text: _moneyText(base.principalCents));
  late final rate = TextEditingController(text: _percentText(base.rateBps));
  late final count = TextEditingController(text: '${base.count}');
  late final interval = TextEditingController(text: base.intervalDays < 2 ? '20' : '${base.intervalDays}');
  late final latePercent = TextEditingController(text: _percentText(base.latePercentBps));
  late final lateDaily = TextEditingController(text: _moneyText(base.lateDailyCents));
  late final lateFixed = TextEditingController(text: _moneyText(base.lateFixedCents));
  late final lateExplainText = TextEditingController(
    text: base.lateExplainText.isEmpty
        ? defaultLateExplanation(
            mode: base.lateMode,
            percentBps: base.latePercentBps,
            dailyCents: base.lateDailyCents,
            fixedCents: base.lateFixedCents,
          )
        : base.lateExplainText,
  );
  late final notes = TextEditingController(text: base.notes);
  late bool lateExplain = base.lateMode == 'sem_mora' ? false : base.lateExplain || base.lateExplainText.isNotEmpty;
  late bool lateExplainTouched = base.lateExplainText.isNotEmpty;
  late RateMode rateMode = base.rateMode;
  late Frequency frequency = base.frequency;
  late DateTime contractDate = base.contractDate;
  late String lateMode = base.lateMode;
  late bool skipSaturday = base.skipSaturday;
  late bool skipSunday = base.skipSunday;
  late bool skipHoliday = base.skipHoliday;
  late int skipWeekdays = base.skipWeekdays;
  bool moreDays = false;
  String? error;

  bool get interestOnly => base.contractMode == ContractMode.apenasJuros;
  bool get customSchedule => base.frequency == Frequency.personalizado;
  bool get locked => widget.hasPayments || interestOnly || customSchedule;
  bool get asksInterval => frequency == Frequency.nDias;

  @override
  void dispose() {
    principal.dispose();
    rate.dispose();
    count.dispose();
    interval.dispose();
    latePercent.dispose();
    lateDaily.dispose();
    lateFixed.dispose();
    lateExplainText.dispose();
    notes.dispose();
    super.dispose();
  }

  LoanDraft? draftFromFields() {
    final value = parseMoney(principal.text);
    final rateBps = parsePercentBps(rate.text);
    final installments = int.tryParse(count.text.trim());
    final every = int.tryParse(interval.text.trim()) ?? 0;
    if (value == null || value <= 0 || rateBps == null || installments == null || installments < 1) return null;
    if (asksInterval && (every < 2 || every > 60)) return null;
    return LoanDraft(
      clientId: base.clientId,
      principalCents: value,
      rateBps: rateBps,
      rateMode: rateMode,
      contractMode: base.contractMode,
      frequency: frequency,
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
      lateExplain: lateMode != 'sem_mora' && lateExplain,
      lateExplainText: lateExplainText.text,
      notes: notes.text,
      skipWeekdays: skipWeekdays,
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

  void save() {
    final lateDraft = LoanDraft(
      clientId: base.clientId,
      principalCents: base.principalCents,
      rateBps: base.rateBps,
      rateMode: base.rateMode,
      contractMode: base.contractMode,
      frequency: base.frequency,
      intervalDays: base.intervalDays,
      count: base.count,
      contractDate: base.contractDate,
      skipSaturday: skipSaturday,
      skipSunday: skipSunday,
      skipHoliday: skipHoliday,
      lateMode: lateMode,
      latePercentBps: parsePercentBps(latePercent.text) ?? 0,
      lateDailyCents: parseMoney(lateDaily.text) ?? 0,
      lateFixedCents: parseMoney(lateFixed.text) ?? 0,
      lateExplain: lateMode != 'sem_mora' && lateExplain,
      lateExplainText: lateExplainText.text,
      notes: notes.text,
      skipWeekdays: skipWeekdays,
    );
    if (locked) {
      widget.repo.updateLoan(widget.loan.id, lateDraft, rebuild: false);
      Navigator.pop(context, true);
      return;
    }
    final full = draftFromFields();
    if (full == null) {
      setState(() => error = asksInterval
          ? 'Informe valor, taxa, parcelas e um intervalo de 2 a 60 dias.'
          : 'Informe valor, taxa e número de parcelas.');
      return;
    }
    widget.repo.updateLoan(widget.loan.id, full, rebuild: true);
    Navigator.pop(context, true);
  }

  void changeLateMode(String next) {
    setState(() {
      lateMode = next;
      if (next == 'percentual_dia' && (parsePercentBps(latePercent.text) ?? 0) == 0) {
        latePercent.text = '1';
      }
      lateExplain = next != 'sem_mora';
    });
    refreshLateExplanation();
  }

  void refreshLateExplanation() {
    if (lateExplainTouched) {
      setState(() {});
      return;
    }
    fillLateExplanation(
      lateExplainText,
      mode: lateMode,
      percent: latePercent,
      daily: lateDaily,
      fixed: lateFixed,
    );
    setState(() {});
  }

  void toggleWeekday(int bit, bool selected) {
    setState(() => skipWeekdays = selected ? skipWeekdays | bit : skipWeekdays & ~bit);
  }

  Widget banner(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = locked ? null : draftFromFields();
    final plan = preview == null ? const <PlannedInstallment>[] : buildSchedule(preview);
    final interest = plan.fold<int>(0, (sum, item) => sum + item.interestCents);
    final total = plan.fold<int>(0, (sum, item) => sum + item.totalCents);
    final parcel = plan.isEmpty ? 0 : plan.first.totalCents;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Editar empréstimo'),
      content: SizedBox(
        width: dialogWidth(context, 620),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cliente: ${widget.loan.clientName}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (widget.hasPayments)
                banner(
                  'Há parcelas pagas — somente mora, dias sem cobrança e observações podem ser alterados.',
                  'Para alterar valor ou parcelas, exclua o contrato e crie outro.',
                )
              else if (interestOnly)
                banner(
                  'Modo "Juros + capital no final" — valor, taxa e prazo não podem ser alterados aqui.',
                  'Para alterar valor ou taxa, exclua o contrato e crie outro.',
                )
              else if (customSchedule)
                banner(
                  'Contrato personalizado — valores e datas das parcelas não podem ser alterados aqui.',
                  'Para alterar as parcelas, exclua o contrato e crie outro.',
                ),
              FieldPair(
                left: TextField(
                  controller: principal,
                  enabled: !locked,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Valor *'),
                  keyboardType: TextInputType.number,
                ),
                right: TextField(
                  controller: rate,
                  enabled: !locked,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Taxa de juros (%) *'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Modo do contrato'),
                child: Text(base.contractMode.label),
              ),
              if (!interestOnly && !customSchedule) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<RateMode>(
                  key: ValueKey('rate-$rateMode'),
                  initialValue: rateMode,
                  decoration: const InputDecoration(labelText: 'Juros aplicado'),
                  items: [for (final mode in RateMode.values) DropdownMenuItem(value: mode, child: Text(mode.label))],
                  onChanged: locked ? null : (next) => setState(() => rateMode = next ?? rateMode),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Frequency>(
                  key: ValueKey('freq-$frequency'),
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Frequência'),
                  items: [
                    for (final item in Frequency.values)
                      if (item != Frequency.personalizado)
                        DropdownMenuItem(value: item, child: Text(item == Frequency.mensal ? 'Parcelado (Mensal)' : item.label)),
                  ],
                  onChanged: locked ? null : (next) => setState(() => frequency = next ?? frequency),
                ),
                if (asksInterval) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: interval,
                    enabled: !locked,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'A cada quantos dias? *'),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 16),
                FieldPair(
                  left: TextField(
                    controller: count,
                    enabled: !locked,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Nº de parcelas *'),
                    keyboardType: TextInputType.number,
                  ),
                  right: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Juros total (R\$)'),
                    child: Text(locked ? '' : (plan.isEmpty ? '' : fmtMoney(interest))),
                  ),
                ),
                const SizedBox(height: 16),
                FieldPair(
                  left: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Valor da parcela (R\$)'),
                    child: Text(locked ? '' : (parcel > 0 ? fmtMoney(parcel) : '')),
                  ),
                  right: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Total a receber'),
                    child: Text(locked ? '' : (plan.isEmpty ? '' : fmtMoney(total)), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: locked ? null : pickDate,
                child: Text('Data do contrato: ${fmtDate(contractDate)}'),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Quando foi fechado', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 16),
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
              if (moreDays || skipWeekdays != 0) ...[
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
              const SizedBox(height: 16),
              LateFeeFields(
                mode: lateMode,
                onMode: changeLateMode,
                percent: latePercent,
                daily: lateDaily,
                fixed: lateFixed,
                explain: lateExplain,
                onExplain: (next) => setState(() => lateExplain = next),
                explainText: lateExplainText,
                onExplainEdited: () => lateExplainTouched = true,
                onValuesChanged: refreshLateExplanation,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Observações (opcional)'),
                maxLines: 2,
              ),
              if (!locked) ...[
                const SizedBox(height: 8),
                const Text(
                  'Ao salvar, as parcelas são recalculadas com os novos dados.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: save, child: const Text('Salvar alterações')),
      ],
    );
  }
}
