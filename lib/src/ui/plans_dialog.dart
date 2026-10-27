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
      'Gestão ilimitada de clientes',
      'Controle completo de empréstimos',
      'Notificações automáticas',
      'Relatórios e análises',
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2416),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC6A15A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 20, color: Color(0xFFE6B325)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seu teste termina em ${widget.daysLeft} dia(s).',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Assine agora para não perder o acesso.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
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
    final buttonText = Text(busy ? 'Abrindo...' : 'Assinar agora');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF151D27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(plan.subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(plan.price, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: AppColors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature, style: const TextStyle(fontSize: 13.5))),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          plan.highlight
              ? FilledButton(
                  onPressed: busy ? null : () => subscribe(plan),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.greenInk,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: buttonText,
                )
              : OutlinedButton(
                  onPressed: busy ? null : () => subscribe(plan),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: Color(0xFF3A4A5A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: buttonText,
                ),
          const SizedBox(height: 10),
          Text(
            plan.yearly,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101820),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        _CardIcon(),
                        SizedBox(height: 14),
                        Text(
                          'Planos e Assinatura',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Gerencie seu acesso ao Acertaí',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        side: BorderSide(color: AppColors.green.withValues(alpha: 0.7)),
                        shape: const CircleBorder(),
                        minimumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.text,
                      ),
                      icon: const Icon(Icons.close, size: 16),
                    ),
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
                const SizedBox(height: 2),
                Text(message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
              ],
              const Text(
                'Cancele quando quiser',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardIcon extends StatelessWidget {
  const _CardIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.45)),
      ),
      child: const Icon(Icons.credit_card, color: AppColors.green, size: 22),
    );
  }
}
