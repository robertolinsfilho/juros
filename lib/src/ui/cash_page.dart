import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../format.dart';
import '../theme.dart';
import 'widgets.dart';

class CashPage extends StatefulWidget {
  const CashPage({super.key, required this.repo});

  final Repo repo;

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  final initial = TextEditingController(text: '0');
  final alert = TextEditingController(text: '0');
  final amount = TextEditingController();
  final note = TextEditingController();

  @override
  void dispose() {
    initial.dispose();
    alert.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void reload() => setState(() {});

  void enable() {
    final opening = parseMoney(initial.text);
    final limit = parseMoney(alert.text);
    if (opening == null || limit == null) {
      showError(context, 'Informe o saldo inicial e o alerta.');
      return;
    }
    widget.repo.enableCash(initialCents: opening, alertCents: limit);
    reload();
  }

  void add(bool outflow) {
    final value = parseMoney(amount.text);
    if (value == null || value <= 0) {
      showError(context, 'Informe um valor.');
      return;
    }
    widget.repo.addCash(outflow: outflow, amountCents: value, note: note.text);
    amount.clear();
    note.clear();
    reload();
  }

  Future<void> reset() async {
    final ok = await confirmAction(
      context,
      'Resetar o caixa',
      'O saldo inicial e todo o histórico de entradas e saídas serão apagados.',
    );
    if (!ok || !mounted) return;
    widget.repo.resetCash();
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final cash = widget.repo.cash();
    if (!cash.enabled) {
      return ListView(
        padding: pagePadding(context),
        children: [
          const PageHeader(title: 'Caixa', subtitle: 'Controle de entradas, saídas e saldo'),
          const SizedBox(height: 16),
          const Panel(
            child: Text(
              'O saldo inicial não muda depois de ativar o caixa. Para corrigir, é preciso resetar e apagar o histórico.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: initial, decoration: const InputDecoration(labelText: 'Saldo inicial'), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          TextField(controller: alert, decoration: const InputDecoration(labelText: 'Alertar quando o saldo ficar abaixo de'), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: enable, child: const Text('Ativar caixa')),
          ),
        ],
      );
    }
    return ListView(
      padding: pagePadding(context),
      children: [
        PageHeader(
          title: 'Caixa',
          subtitle: cash.low ? 'Saldo abaixo do alerta' : 'Saldo atual da operação',
          actions: [
            OutlinedButton(onPressed: reset, child: const Text('Resetar caixa')),
          ],
        ),
        const SizedBox(height: 16),
        MetricCard(
          label: 'SALDO',
          value: fmtMoney(cash.balanceCents),
          caption: 'alerta em ${fmtMoney(cash.alertCents)}',
          accent: cash.low ? AppColors.amber : AppColors.green,
        ),
        const SizedBox(height: 16),
        FieldPair(
          left: TextField(controller: amount, decoration: const InputDecoration(labelText: 'Valor'), keyboardType: TextInputType.number),
          right: TextField(controller: note, decoration: const InputDecoration(labelText: 'Observação')),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(onPressed: () => add(false), child: const Text('Entrada')),
            OutlinedButton(onPressed: () => add(true), child: const Text('Saída')),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: cash.entries.isEmpty
              ? const EmptyHint(icon: Icons.account_balance_wallet_outlined, title: 'Sem lançamentos', body: 'As movimentações aparecem aqui.')
              : Column(
                  children: [
                    for (final entry in cash.entries)
                      ListTile(
                        title: Text(_kindLabel(entry.kind)),
                        subtitle: Text(entry.note.isEmpty ? entry.createdAt.substring(0, 10) : entry.note),
                        trailing: Text(
                          '${entry.kind == 'saida' ? '-' : '+'}${fmtMoney(entry.amountCents)}',
                          style: TextStyle(color: entry.kind == 'saida' ? AppColors.red : AppColors.green, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

String _kindLabel(String kind) {
  return switch (kind) {
    'saida' => 'Saída',
    'saldo_inicial' => 'Saldo inicial',
    _ => 'Entrada',
  };
}
