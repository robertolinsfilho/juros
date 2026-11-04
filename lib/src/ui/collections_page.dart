import 'package:flutter/material.dart';

import '../alerts.dart';
import '../data/repository.dart';
import '../format.dart';
import '../links.dart';
import '../messages/builders.dart';
import '../notify.dart';
import 'message_dialog.dart';
import '../theme.dart';
import 'widgets.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key, required this.repo, this.onChanged});

  final Repo repo;
  final VoidCallback? onChanged;

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  DateTime cursor = DateTime.now();
  late DateTime selected = dateOnly(DateTime.now());
  String permission = '';

  @override
  void initState() {
    super.initState();
    noticePermission().then((value) {
      if (mounted) setState(() => permission = value);
    });
  }

  void changed() {
    setState(() {});
    widget.onChanged?.call();
  }

  void shift(int months) {
    final next = DateTime(cursor.year, cursor.month + months, 1);
    setState(() {
      cursor = next;
      selected = DateTime(next.year, next.month, 1);
    });
  }

  Future<void> receive(InstallmentRecord item) async {
    final late = item.liveLateCents(DateTime.now());
    final ok = await confirmAction(
      context,
      'Registrar recebimento',
      'Confirmar ${fmtMoney(item.faceCents + late)} de ${item.clientName}?',
    );
    if (!ok || !mounted) return;
    widget.repo.payInstallment(item.id);
    changed();
    await offerPaymentMessage(context, widget.repo, item);
  }

  Future<void> charge(InstallmentRecord item) async {
    final opened = await openWhatsApp(
      phone: item.clientPhone,
      message: MessageBuilder(widget.repo).charge(item),
    );
    if (!opened && mounted) showError(context, 'Não foi possível abrir o WhatsApp.');
  }

  Future<void> remind(InstallmentRecord item) async {
    if (item.clientPhone.trim().isEmpty) {
      showError(context, '${item.clientName} está sem telefone.');
      return;
    }
    final opened = await openWhatsApp(
      phone: item.clientPhone,
      message: MessageBuilder(widget.repo).charge(item),
    );
    if (!opened) {
      if (mounted) showError(context, 'Não foi possível abrir o WhatsApp.');
      return;
    }
    widget.repo.markReminderSent(item);
    if (mounted) changed();
  }

  Future<void> details(InstallmentRecord item) {
    return showChargeDetails(context, widget.repo, item);
  }

  Future<void> promise(InstallmentRecord item) async {
    final picked = await showPromisePicker(context, item);
    if (picked == null || !mounted) return;
    widget.repo.setPromiseDate(item.id, picked.isEmpty ? null : picked);
    changed();
  }

  Future<void> enableNotices() async {
    final shown = await deliverPaymentNotices(widget.repo, ask: true);
    final next = await noticePermission();
    if (!mounted) return;
    setState(() => permission = next);
    if (!shown && next == 'denied') {
      showError(context, 'O navegador bloqueou o aviso. Libere as notificações deste site nas configurações.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final pulse = widget.repo.monthPulse(selected);
    final amounts = widget.repo.dueAmountsInMonth(cursor, today);
    final promises = widget.repo.promiseDaysInMonth(cursor);
    final due = widget.repo.dueOn(selected);
    final dueTotal = due.fold<int>(0, (sum, item) => sum + item.dueCents(today));
    final alerts = widget.repo.paymentAlerts(today);
    final reminders = widget.repo.dueReminders(today);
    final lead = widget.repo.reminderDays;
    final names = const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    final first = DateTime(cursor.year, cursor.month, 1);
    final days = DateTime(cursor.year, cursor.month + 1, 0).day;
    final leading = first.weekday % 7;
    return ListView(
      padding: pagePadding(context),
      children: [
        PageHeader(
          title: 'Cobranças',
          subtitle: '${due.length} em aberto no dia escolhido',
        ),
        const SizedBox(height: 16),
        _Unpaid(
          items: alerts.unpaid,
          today: today,
          permission: permission,
          onCharge: charge,
          onReceive: receive,
          onDetails: details,
          onPromise: promise,
          onEnable: enableNotices,
        ),
        const SizedBox(height: 16),
        _Reminders(
          days: lead,
          items: reminders,
          onDays: (days) {
            widget.repo.setReminderDays(days);
            changed();
          },
          onRemind: remind,
        ),
        const SizedBox(height: 16),
        metricGrid([
          MetricCard(label: 'PREVISTO NO MÊS', value: fmtMoney(pulse.expected), caption: 'parcelas com vencimento no mês'),
          MetricCard(label: 'RECEBIDO NO MÊS', value: fmtMoney(pulse.received), caption: 'pela data do pagamento', accent: AppColors.green),
          MetricCard(
            label: 'RECEBIDO NO DIA',
            value: fmtMoney(pulse.receivedToday),
            caption: isoDate(today) == isoDate(selected) ? 'hoje' : fmtDate(selected),
          ),
          MetricCard(
            label: 'EMPRESTADO NO DIA',
            value: fmtMoney(pulse.lentToday),
            caption: isoDate(today) == isoDate(selected) ? 'contratos de hoje' : fmtDate(selected),
          ),
        ]),
        const SizedBox(height: 16),
        sideBySide(
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => shift(-1), icon: const Icon(Icons.chevron_left)),
                    Expanded(
                      child: Text(
                        '${_monthName(cursor.month)} ${cursor.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(onPressed: () => shift(1), icon: const Icon(Icons.chevron_right)),
                  ],
                ),
                const Text(
                  'O ponto amarelo é o dia marcado para avisar desta cobrança. O vencimento continua no dia original.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Row(
                  children: [
                    for (final name in names)
                      Expanded(child: Center(child: Text(name, style: const TextStyle(color: AppColors.muted)))),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 7,
                  childAspectRatio: 0.72,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                    for (var day = 1; day <= days; day++)
                      _DayCell(
                        day: day,
                        amount: amounts[day] ?? 0,
                        reminded: promises.contains(day),
                        overdue: DateTime(cursor.year, cursor.month, day).isBefore(dateOnly(today)),
                        selected: selected.year == cursor.year && selected.month == cursor.month && selected.day == day,
                        onTap: () => setState(() => selected = DateTime(cursor.year, cursor.month, day)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmtDate(selected), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (dueTotal > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Em aberto ${fmtMoney(dueTotal)}', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                  ),
                if (due.isEmpty)
                  const EmptyHint(icon: Icons.event_available, title: 'Dia livre', body: 'Nenhuma parcela em aberto nesta data.')
                else
                  for (final item in due)
                    RecordTile(
                      title: item.clientName,
                      subtitle: _dueSubtitle(item, today, selected: isoDate(selected)),
                      actions: _chargeActions(
                        item: item,
                        today: today,
                        onCharge: () => charge(item),
                        onReceive: () => receive(item),
                        onDetails: () => details(item),
                        onPromise: () => promise(item),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Unpaid extends StatelessWidget {
  const _Unpaid({
    required this.items,
    required this.today,
    required this.permission,
    required this.onCharge,
    required this.onReceive,
    required this.onDetails,
    required this.onPromise,
    required this.onEnable,
  });

  final List<InstallmentRecord> items;
  final DateTime today;
  final String permission;
  final ValueChanged<InstallmentRecord> onCharge;
  final ValueChanged<InstallmentRecord> onReceive;
  final ValueChanged<InstallmentRecord> onDetails;
  final ValueChanged<InstallmentRecord> onPromise;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final active = permission == 'granted';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quem não pagou', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'O aviso chega aqui no site e também no aplicativo, quando a pessoa instala o site pelo navegador.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: active ? null : onEnable,
            child: Text(active ? 'Avisos ativos neste aparelho' : 'Ativar avisos neste aparelho'),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text('Ninguém em atraso.', style: TextStyle(color: AppColors.muted))
          else
            for (final item in items)
              RecordTile(
                title: item.clientName,
                subtitle: _dueSubtitle(item, today),
                actions: _chargeActions(
                  item: item,
                  today: today,
                  moneyColor: AppColors.red,
                  onCharge: () => onCharge(item),
                  onReceive: () => onReceive(item),
                  onDetails: () => onDetails(item),
                  onPromise: () => onPromise(item),
                ),
              ),
        ],
      ),
    );
  }
}

class _Reminders extends StatelessWidget {
  const _Reminders({
    required this.days,
    required this.items,
    required this.onDays,
    required this.onRemind,
  });

  final int days;
  final List<InstallmentRecord> items;
  final ValueChanged<int> onDays;
  final ValueChanged<InstallmentRecord> onRemind;

  @override
  Widget build(BuildContext context) {
    final reach = days == 0 ? 'só no dia do vencimento' : 'no dia e até $days ${days == 1 ? 'dia' : 'dias'} antes';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Avisos pelo WhatsApp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Quem tem cobrança chegando entra aqui, $reach. O aviso abre o WhatsApp com a mensagem pronta e não se repete.',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [(0, 'Só no dia'), (1, '1 dia antes'), (2, '2 dias antes'), (3, '3 dias antes')])
                ChoiceChip(
                  label: Text(option.$2),
                  selected: days == option.$1,
                  onSelected: (_) => onDays(option.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text('Nenhum aviso pendente.', style: TextStyle(color: AppColors.muted))
          else
            for (final item in items)
              RecordTile(
                title: item.clientName,
                subtitle: '${item.number}/${item.count} · ${fmtDateIso(item.dueDate)} · ${fmtMoney(item.faceCents)}',
                actions: [
                  FilledButton(onPressed: () => onRemind(item), child: const Text('Avisar')),
                ],
              ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.amount,
    required this.reminded,
    required this.overdue,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final int amount;
  final bool reminded;
  final bool overdue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = amount <= 0 ? AppColors.muted : overdue ? AppColors.red : AppColors.amber;
    final tip = [
      if (amount > 0) fmtMoney(amount),
      if (reminded) 'Lembrete neste dia',
    ].join(' · ');
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? AppColors.green.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day', style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              if (amount > 0)
                Text(
                  _shortMoney(amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
                ),
              if (reminded)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _dueSubtitle(InstallmentRecord item, DateTime today, {String? selected}) {
  final late = item.liveLateCents(today);
  final base = 'Parcela ${item.number}/${item.count} · ${fmtDateIso(item.dueDate)}';
  final money = late <= 0 ? base : '$base · parcela ${fmtMoney(item.faceCents)} + mora ${fmtMoney(late)}';
  final promise = item.promiseDate;
  if (promise == null || promise != selected || promise == item.dueDate) return money;
  return '$money · lembrete neste dia';
}

List<Widget> _chargeActions({
  required InstallmentRecord item,
  required DateTime today,
  required VoidCallback onCharge,
  required VoidCallback onReceive,
  required VoidCallback onDetails,
  required VoidCallback onPromise,
  Color? moneyColor,
}) {
  return [
    Text(
      fmtMoney(item.dueCents(today)),
      style: TextStyle(color: moneyColor, fontWeight: moneyColor == null ? null : FontWeight.w700),
    ),
    TextButton(onPressed: onCharge, child: const Text('Cobrar')),
    FilledButton(onPressed: onReceive, child: const Text('Receber')),
    _PromiseButton(item: item, today: today, onPressed: onPromise),
    IconButton(
      tooltip: 'Ver detalhes',
      visualDensity: VisualDensity.compact,
      onPressed: onDetails,
      icon: const Icon(Icons.visibility_outlined, size: 20),
    ),
  ];
}

class _PromiseButton extends StatelessWidget {
  const _PromiseButton({required this.item, required this.today, required this.onPressed});

  final InstallmentRecord item;
  final DateTime today;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final promise = item.promiseDate;
    final expired = promise != null && parseIsoDate(promise).isBefore(dateOnly(today));
    final color = promise == null ? AppColors.muted : expired ? AppColors.red : AppColors.amber;
    final when = promise == null ? null : _dayMonth(promise);
    final tip = promise == null
        ? 'Definir lembrete'
        : expired
        ? 'Lembrete vencido: $when'
        : 'Lembrete: $when';
    return Tooltip(
      message: tip,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(promise == null ? Icons.notifications_none : Icons.notifications_active, size: 18, color: color),
            if (when != null) ...[
              const SizedBox(width: 4),
              Text(when, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }
}

String _dayMonth(String iso) {
  final date = parseIsoDate(iso);
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

/// Dia escolhido para o lembrete. Vazio remove. Nulo cancela.
Future<String?> showPromisePicker(BuildContext context, InstallmentRecord item) {
  final due = parseIsoDate(item.dueDate);
  final current = item.promiseDate == null ? due : parseIsoDate(item.promiseDate!);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Lembrete · Parcela ${item.number}'),
      content: SizedBox(
        width: 320,
        height: 430,
        child: Column(
          children: [
            const Text('Que dia o cliente prometeu pagar?', textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'Vence em ${fmtDateIso(item.dueDate)} — o lembrete não muda o vencimento.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CalendarDatePicker(
                initialDate: current,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                onDateChanged: (value) => Navigator.pop(context, isoDate(value)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (item.promiseDate != null)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Remover lembrete', style: TextStyle(color: AppColors.red)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      ],
    ),
  );
}

Future<void> showChargeDetails(BuildContext context, Repo repo, InstallmentRecord item) {
  final today = DateTime.now();
  final loan = repo.loanById(item.loanId, today);
  final parts = repo.installmentsOf(item.loanId);
  final late = item.liveLateCents(today);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(item.clientName),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Parcela ${item.number}/${item.count}'),
              const SizedBox(height: 4),
              Text('Vencimento ${fmtDateIso(item.dueDate)}'),
              const SizedBox(height: 4),
              Text('Em aberto ${fmtMoney(item.dueCents(today))}', style: const TextStyle(fontWeight: FontWeight.w700)),
              if (late > 0) ...[
                const SizedBox(height: 4),
                Text('Parcela ${fmtMoney(item.faceCents)} + mora ${fmtMoney(late)}'),
              ],
              const SizedBox(height: 4),
              Text(
                item.promiseDate == null
                    ? 'Sem lembrete'
                    : 'Lembrete ${fmtDateIso(item.promiseDate!)} — não muda o vencimento',
              ),
              if (item.clientPhone.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.clientPhone),
              ],
              if (loan != null) ...[
                const SizedBox(height: 4),
                Text(loan.typeLabel, style: const TextStyle(color: AppColors.muted)),
              ],
              const SizedBox(height: 16),
              const Text('Parcelas deste contrato', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final part in parts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${part.number}/${part.count} · ${fmtDateIso(part.dueDate)} · ${part.paidAt != null ? 'pago' : part.isOpen ? fmtMoney(part.dueCents(today)) : part.status}',
                    style: TextStyle(
                      color: part.id == item.id ? AppColors.text : AppColors.muted,
                      fontWeight: part.id == item.id ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    ),
  );
}

String _shortMoney(int cents) {
  final reais = cents / 100;
  if (reais >= 1000000) return '${_trim(reais / 1000000)} mi';
  if (reais >= 1000) return '${_trim(reais / 1000)} mil';
  return reais.round().toString();
}

String _trim(double value) {
  final text = value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}

String _monthName(int month) {
  const names = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  return names[month - 1];
}
