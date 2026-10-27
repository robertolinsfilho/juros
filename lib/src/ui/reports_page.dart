import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../format.dart';
import '../theme.dart';
import 'widgets.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.repo});

  final Repo repo;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int months = 1;

  (DateTime, DateTime) get range {
    final today = dateOnly(DateTime.now());
    if (months == 0) return (DateTime(2000), today);
    if (months == 1) return (DateTime(today.year, today.month, 1), today);
    return (DateTime(today.year, today.month - (months - 1), 1), today);
  }

  @override
  Widget build(BuildContext context) {
    final bounds = range;
    final data = widget.repo.report(bounds.$1, bounds.$2);
    return ListView(
      padding: pagePadding(context),
      children: [
        PageHeader(
          title: 'Relatórios',
          subtitle: '${fmtDate(bounds.$1)} até ${fmtDate(bounds.$2)}',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final item in const [(1, 'Este mês'), (3, '3 meses'), (6, '6 meses'), (12, '12 meses'), (0, 'Tudo')])
              ChoiceChip(
                label: Text(item.$2),
                selected: months == item.$1,
                onSelected: (_) => setState(() => months = item.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        metricGrid([
          MetricCard(label: 'CAPITAL EMPRESTADO', value: fmtMoney(data.lentCents), caption: 'contratos no período'),
          MetricCard(label: 'LUCRO', value: fmtMoney(data.profitCents), caption: 'juros + mora recebidos', accent: AppColors.green),
          MetricCard(label: 'EM ATRASO', value: fmtMoney(data.overdueCents), caption: 'situação de hoje', accent: AppColors.red),
          MetricCard(label: 'INADIMPLÊNCIA', value: '${(data.delinquency * 100).toStringAsFixed(1)}%', caption: 'parcelas atrasadas / já vencidas'),
        ]),
        const SizedBox(height: 12),
        metricGrid([
          MetricCard(label: 'JUROS RECEBIDOS', value: fmtMoney(data.interestCents), caption: 'sem a mora'),
          MetricCard(label: 'MORA RECEBIDA', value: fmtMoney(data.lateCents), caption: 'atraso cobrado'),
          MetricCard(label: 'CAPITAL RECUPERADO', value: fmtMoney(data.capitalBackCents), caption: 'principal que voltou'),
          MetricCard(label: 'TOTAL RECEBIDO', value: fmtMoney(data.receivedCents), caption: 'capital + juros + mora'),
        ]),
        const SizedBox(height: 12),
        sideBySide(
          MetricCard(label: 'CAPITAL EM ABERTO', value: fmtMoney(data.openCapitalCents), caption: 'principal ainda na rua'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recebido por tipo', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text('Parcelado: ${fmtMoney(data.amortizedCents)}'),
                const SizedBox(height: 6),
                Text('Juros + capital no final: ${fmtMoney(data.interestOnlyCents)}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
