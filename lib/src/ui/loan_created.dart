import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repository.dart';
import '../domain/schedule.dart';
import '../format.dart';
import '../links.dart';
import '../messages/builders.dart';
import '../theme.dart';
import 'widgets.dart';

String frequencyAdjective(Frequency frequency, int intervalDays) {
  return switch (frequency) {
    Frequency.diario => 'Diário',
    Frequency.semanal => 'Semanal',
    Frequency.dezDias => 'Decendial',
    Frequency.quinzenal => 'Quinzenal',
    Frequency.mensal => 'Mensal',
    Frequency.nDias => 'a cada $intervalDays dias',
    Frequency.personalizado => 'Personalizado',
  };
}

class LoanSummaryRow {
  const LoanSummaryRow(this.label, this.dueIso, this.cents);

  final String label;
  final String dueIso;
  final int cents;
}

class LoanSummary {
  LoanSummary._({
    required this.clientName,
    required this.phone,
    required this.interestOnly,
    required this.principalCents,
    required this.secondLabel,
    required this.secondValue,
    required this.thirdLabel,
    required this.thirdValue,
    required this.totalCents,
    required this.rows,
    required this.message,
  });

  factory LoanSummary.load(Repo repo, int loanId) {
    final loan = repo.loanById(loanId)!;
    final installments = repo.installmentsOf(loanId);
    final interestOnly = loan.contractMode == ContractMode.apenasJuros.code;
    final frequency = FrequencyLabel.parse(loan.frequency);
    final message = MessageBuilder(repo).registered(loanId);
    if (interestOnly) {
      final interestRows = [for (final item in installments) if (item.principalCents == 0) item];
      final first = interestRows.isEmpty ? null : interestRows.first;
      return LoanSummary._(
        clientName: loan.clientName,
        phone: loan.clientPhone,
        interestOnly: true,
        principalCents: loan.principalCents,
        secondLabel: 'Juros ${frequencyAdjective(frequency, loan.intervalDays)}',
        secondValue: fmtMoney(first?.faceCents ?? 0),
        thirdLabel: 'Capital a devolver',
        thirdValue: fmtMoney(loan.principalCents),
        totalCents: loan.principalCents,
        rows: [
          for (final item in interestRows) LoanSummaryRow('Juros ${item.number}', item.dueDate, item.faceCents),
        ],
        message: message,
      );
    }
    final total = installments.fold<int>(0, (sum, item) => sum + item.faceCents);
    final first = installments.isEmpty ? 0 : installments.first.faceCents;
    return LoanSummary._(
      clientName: loan.clientName,
      phone: loan.clientPhone,
      interestOnly: false,
      principalCents: loan.principalCents,
      secondLabel: 'Parcelas',
      secondValue: '${installments.length}x de ${fmtMoney(first)}',
      thirdLabel: 'Total a pagar',
      thirdValue: fmtMoney(total),
      totalCents: total,
      rows: [
        for (final item in installments) LoanSummaryRow('Parc. ${item.number}', item.dueDate, item.faceCents),
      ],
      message: message,
    );
  }

  final String clientName;
  final String phone;
  final bool interestOnly;
  final int principalCents;
  final String secondLabel;
  final String secondValue;
  final String thirdLabel;
  final String thirdValue;
  final int totalCents;
  final List<LoanSummaryRow> rows;
  final String message;
}

Future<void> showLoanCreated(BuildContext context, Repo repo, int loanId) {
  final summary = LoanSummary.load(repo, loanId);
  return showDialog<void>(
    context: context,
    builder: (context) => _LoanCreatedDialog(summary: summary),
  );
}

class _LoanCreatedDialog extends StatelessWidget {
  const _LoanCreatedDialog({required this.summary});

  final LoanSummary summary;

  Future<void> sendWhatsApp(BuildContext context) async {
    final opened = await openWhatsApp(
      phone: summary.phone,
      message: summary.message,
    );
    if (!opened && context.mounted) {
      showError(context, 'Cliente sem telefone válido. Cadastre o WhatsApp do cliente.');
    }
  }

  Future<void> copy(BuildContext context) async {
    final plain = summary.message.replaceAll('*', '').replaceAll('_', '');
    await Clipboard.setData(ClipboardData(text: plain));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resumo copiado!')));
  }

  Widget tile(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.green.withValues(alpha: 0.10) : AppColors.cardAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: highlight ? AppColors.green.withValues(alpha: 0.35) : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
              color: highlight ? AppColors.green : AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: highlight ? AppColors.green : AppColors.text),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth(context, 440)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.green.withValues(alpha: 0.10),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(99),
                        child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 18, color: AppColors.muted)),
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle_outline, size: 36, color: AppColors.green),
                    ),
                    const SizedBox(height: 14),
                    const Text('Empréstimo Criado!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Contrato registrado com sucesso', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: tile('Cliente', summary.clientName)),
                        const SizedBox(width: 8),
                        Expanded(child: tile('Valor emprestado', fmtMoney(summary.principalCents))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: tile(summary.secondLabel, summary.secondValue)),
                        const SizedBox(width: 8),
                        Expanded(child: tile(summary.thirdLabel, summary.thirdValue, highlight: true)),
                      ],
                    ),
                    if (summary.rows.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'VENCIMENTOS',
                        style: TextStyle(fontSize: 11, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: AppColors.muted),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final row in summary.rows)
                              Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.cardAlt.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(row.label, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
                                    Expanded(child: Text(fmtDateIso(row.dueIso), style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                                    Expanded(
                                      child: Text(
                                        fmtMoney(row.cents),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => sendWhatsApp(context),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Enviar via WhatsApp'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => copy(context),
                            icon: const Icon(Icons.copy_outlined, size: 16),
                            label: const Text('Copiar Resumo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Fechar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
