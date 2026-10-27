import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../format.dart';
import '../links.dart';
import '../theme.dart';
import 'client_form.dart';
import 'loan_form.dart';
import 'widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.repo});

  final Repo repo;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DashboardData data = widget.repo.dashboard();

  void reload() => setState(() => data = widget.repo.dashboard());

  Future<void> createClient() async {
    if (await showClientForm(context, widget.repo) && mounted) reload();
  }

  Future<void> createLoan() async {
    if (await showLoanForm(context, widget.repo) && mounted) reload();
  }

  Future<void> charge(InstallmentRecord item) async {
    final late = item.liveLateCents(DateTime.now());
    final opened = await openWhatsApp(
      phone: item.clientPhone,
      message: chargeMessage(
        client: item.clientName,
        number: item.number,
        count: item.count,
        cents: item.faceCents + late,
        dueIso: item.dueDate,
        creditor: widget.repo.setting('creditor_name'),
        pix: widget.repo.setting('pix_key'),
        lateCents: late,
      ),
    );
    if (!opened && mounted) showError(context, 'Não foi possível abrir o WhatsApp.');
  }

  @override
  Widget build(BuildContext context) {
    final cash = widget.repo.cash();
    return ListView(
      padding: pagePadding(context),
      children: [
        PageHeader(
          title: 'Dashboard',
          subtitle: 'Resumo da operação',
          actions: [
            OutlinedButton.icon(onPressed: createClient, icon: const Icon(Icons.person_add_alt), label: const Text('Novo cliente')),
            FilledButton.icon(onPressed: createLoan, icon: const Icon(Icons.add), label: const Text('Novo empréstimo')),
          ],
        ),
        if (cash.low) ...[
          const SizedBox(height: 16),
          Panel(
            child: Text(
              'Caixa abaixo do alerta: ${fmtMoney(cash.balanceCents)}',
              style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 16),
        metricGrid([
          MetricCard(label: 'PREVISTO A RECEBER', value: fmtMoney(data.expectedCents), caption: 'parcelas em aberto'),
          MetricCard(label: 'EM ATRASO', value: fmtMoney(data.overdueCents), caption: 'vencidas e não pagas', accent: AppColors.red),
          MetricCard(label: 'RECEBIDO NO MÊS', value: fmtMoney(data.receivedMonthCents), caption: 'pela data do pagamento', accent: AppColors.green),
          MetricCard(label: 'CLIENTES', value: '${data.clientCount}', caption: 'cadastrados'),
        ]),
        const SizedBox(height: 12),
        sideBySide(
          MetricCard(label: 'CAPITAL NA RUA', value: fmtMoney(data.capitalCents), caption: 'principal ainda em aberto', accent: AppColors.green),
          MetricCard(label: 'JUROS DO MÊS', value: fmtMoney(data.profitMonthCents), caption: 'juros a receber neste mês', accent: AppColors.amber),
        ),
        const SizedBox(height: 12),
        sideBySide(
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cobranças de hoje', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (data.today.isEmpty)
                  const EmptyHint(icon: Icons.notifications_none, title: 'Nada para hoje', body: 'Nenhuma parcela vence hoje.')
                else
                  for (final item in data.today) _DueRow(item: item, onCharge: () => charge(item)),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Empréstimos por status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),
                _Count(label: 'Aberto', value: data.openLoans, color: AppColors.blue),
                _Count(label: 'Atrasado', value: data.lateLoans, color: AppColors.red),
                _Count(label: 'Quitado', value: data.settledLoans, color: AppColors.green),
                _Count(label: 'Perdido', value: data.lostLoans, color: AppColors.muted),
                const SizedBox(height: 8),
                Text(
                  'Inadimplência ${(data.delinquency * 100).toStringAsFixed(1)}% · ${data.overdueInstallments} parcelas atrasadas',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        sideBySide(
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Próximos 7 dias', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (data.nextDays.isEmpty)
                  const EmptyHint(icon: Icons.event_available, title: 'Sem vencimentos', body: 'Nada programado nesta semana.')
                else
                  for (final item in data.nextDays.take(8))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.clientName),
                      subtitle: Text(fmtDateIso(item.dueDate)),
                      trailing: Text(fmtMoney(item.dueCents(DateTime.now()))),
                    ),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Semanas do mês', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                for (final week in data.weeks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(week.label, style: const TextStyle(color: AppColors.muted)),
                        Text(fmtMoney(week.expectedCents)),
                        Text('recebido ${fmtMoney(week.receivedCents)}', style: const TextStyle(color: AppColors.green)),
                      ],
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

class _DueRow extends StatelessWidget {
  const _DueRow({required this.item, required this.onCharge});

  final InstallmentRecord item;
  final VoidCallback onCharge;

  @override
  Widget build(BuildContext context) {
    return RecordTile(
      title: item.clientName,
      subtitle: 'Parcela ${item.number}/${item.count}',
      actions: [
        Text(fmtMoney(item.dueCents(DateTime.now()))),
        TextButton(onPressed: onCharge, child: const Text('Cobrar')),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
