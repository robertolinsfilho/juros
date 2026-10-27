import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../links.dart';
import '../theme.dart';

class _Plan {
  const _Plan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.yearly,
    required this.features,
    required this.highlight,
  });

  final String id;
  final String title;
  final String subtitle;
  final String price;
  final String yearly;
  final List<String> features;
  final bool highlight;
}

const _plans = [
  _Plan(
    id: 'mensal',
    title: 'Plano Mensal',
    subtitle: 'Acesso completo',
    price: 'R\$ 49,99/mês',
    yearly: 'ou R\$ 480,00 por ano · o prazo você escolhe no checkout',
    features: [
      'Clientes e empréstimos sem limite',
      'Controle completo de parcelas e recebimentos',
      'Cobrança e confirmação pelo WhatsApp',
      'Relatórios e acompanhamento do caixa',
      'Suporte prioritário',
    ],
    highlight: true,
  ),
  _Plan(
    id: 'app_relatorio',
    title: 'Aplicativo + Relatório',
    subtitle: 'Tudo do plano, mais o resumo diário no WhatsApp',
    price: 'R\$ 69,90/mês',
    yearly: 'ou R\$ 499,00 por ano · o prazo você escolhe no checkout',
    features: [],
    highlight: false,
  ),
];

Future<void> showPlansDialog(BuildContext context, {required AuthApi auth, required String token, required int daysLeft}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _PlansDialog(auth: auth, token: token, daysLeft: daysLeft),
  );
}

class _PlansDialog extends StatefulWidget {
  const _PlansDialog({required this.auth, required this.token, required this.daysLeft});

  final AuthApi auth;
  final String token;
  final int daysLeft;

  @override
  State<_PlansDialog> createState() => _PlansDialogState();
}

class _PlansDialogState extends State<_PlansDialog> {
  String? busyPlan;
  String? message;
  String? checkoutUrl;

  Future<void> subscribe(_Plan plan) async {
    setState(() {
      busyPlan = plan.id;
      message = null;
    });
    try {
      final result = await widget.auth.subscribe(widget.token, plan.id);
      if (!mounted) return;
      if (result.checkoutUrl.isNotEmpty) {
        await openExternal(Uri.parse(result.checkoutUrl));
        if (mounted) setState(() => checkoutUrl = result.checkoutUrl);
      } else {
        setState(() => message = result.message.isEmpty ? 'Pedido registrado.' : result.message);
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => message = error.message);
    } finally {
      if (mounted) setState(() => busyPlan = null);
    }
  }

  Widget banner() {
    final vencido = widget.daysLeft <= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vencido ? 'Seu teste terminou.' : 'Seu teste termina em ${widget.daysLeft} ${widget.daysLeft == 1 ? 'dia' : 'dias'}.',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  vencido ? 'Assine para voltar a usar o sistema.' : 'Assine agora para não perder o acesso.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget planCard(_Plan plan) {
    final busy = busyPlan == plan.id;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: plan.highlight ? AppColors.green.withValues(alpha: 0.06) : AppColors.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: plan.highlight ? AppColors.green.withValues(alpha: 0.55) : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 8,
            runSpacing: 4,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 230,
                    child: Text(plan.subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ),
                ],
              ),
              Text(plan.price, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 15, color: AppColors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: plan.highlight
                ? FilledButton(
                    onPressed: busy ? null : () => subscribe(plan),
                    child: Text(busy ? 'Abrindo...' : 'Assinar agora'),
                  )
                : OutlinedButton(
                    onPressed: busy ? null : () => subscribe(plan),
                    child: Text(busy ? 'Abrindo...' : 'Assinar agora'),
                  ),
          ),
          const SizedBox(height: 8),
          Text(plan.yearly, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.credit_card, color: AppColors.green, size: 22),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Planos e Assinatura',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Gerencie seu acesso ao Acertaí',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        side: BorderSide(color: AppColors.green.withValues(alpha: 0.5)),
                        foregroundColor: AppColors.text,
                      ),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                banner(),
                const SizedBox(height: 14),
                for (final plan in _plans) ...[
                  planCard(plan),
                  const SizedBox(height: 12),
                ],
                if (message != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(message!, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Pagamento combinado direto com o suporte · cancele quando quiser',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
