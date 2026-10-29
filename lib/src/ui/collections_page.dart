import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../format.dart';
import '../links.dart';
import '../messages/builders.dart';
import 'message_dialog.dart';
import '../theme.dart';
import 'widgets.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key, required this.repo});

  final Repo repo;

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  DateTime cursor = DateTime.now();
  late DateTime selected = dateOnly(DateTime.now());

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
    setState(() {});
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
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pulse = widget.repo.monthPulse(cursor);
    final counts = widget.repo.dueCountsInMonth(cursor);
    final due = widget.repo.dueOn(selected);
    final reminders = widget.repo.dueReminders(DateTime.now());
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
        _Reminders(
          days: lead,
          items: reminders,
          onDays: (days) {
            widget.repo.setReminderDays(days);
            setState(() {});
          },
          onRemind: remind,
        ),
        const SizedBox(height: 16),
        metricGrid([
          MetricCard(label: 'PREVISTO NO MÊS', value: fmtMoney(pulse.expected), caption: 'parcelas com vencimento no mês'),
          MetricCard(label: 'RECEBIDO NO MÊS', value: fmtMoney(pulse.received), caption: 'pela data do pagamento', accent: AppColors.green),
          MetricCard(label: 'RECEBIDO NO DIA', value: fmtMoney(pulse.receivedToday), caption: isoDate(DateTime.now()) == isoDate(selected) ? 'hoje' : fmtDate(selected)),
          MetricCard(label: 'EMPRESTADO NO DIA', value: fmtMoney(pulse.lentToday), caption: 'contratos de hoje'),
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
                Row(
                  children: [
                    for (final name in names)
                      Expanded(child: Center(child: Text(name, style: const TextStyle(color: AppColors.muted)))),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                    for (var day = 1; day <= days; day++)
                      _DayCell(
                        day: day,
                        count: counts[day] ?? 0,
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
                if (due.isEmpty)
                  const EmptyHint(icon: Icons.event_available, title: 'Dia livre', body: 'Nenhuma parcela em aberto nesta data.')
                else
                  for (final item in due)
                    RecordTile(
                      title: item.clientName,
                      subtitle: 'Parcela ${item.number}/${item.count}',
                      actions: [
                        Text(fmtMoney(item.dueCents(DateTime.now()))),
                        TextButton(onPressed: () => charge(item), child: const Text('Cobrar')),
                        FilledButton(onPressed: () => receive(item), child: const Text('Receber')),
                      ],
                    ),
              ],
            ),
          ),
        ),
      ],
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
  const _DayCell({required this.day, required this.count, required this.selected, required this.onTap});

  final int day;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            Text('$day'),
            if (count > 0)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

String _monthName(int month) {
  const names = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  return names[month - 1];
}
