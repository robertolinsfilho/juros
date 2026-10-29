import 'package:flutter/material.dart';

import '../theme.dart';

/// Laranja dos avisos de teste (diferente do verde da marca, para chamar atenção).
class AccessColors {
  static const orange = Color(0xFFF0872B);
  static const orangeInk = Color(0xFF2A1403);
}

/// Faixa fina no topo do sistema enquanto o teste ou a assinatura estão no fim.
class TrialBar extends StatelessWidget {
  const TrialBar({super.key, required this.text, required this.onSubscribe});

  final String text;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AccessColors.orange,
      child: InkWell(
        onTap: onSubscribe,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule, size: 15, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Assinar agora →',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso de teste dentro do conteúdo, com o botão Assinar.
class TrialNotice extends StatelessWidget {
  const TrialNotice({super.key, required this.daysLeft, required this.onSubscribe});

  final int daysLeft;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final vencido = daysLeft <= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AccessColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AccessColors.orange.withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AccessColors.orange.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, size: 17, color: AccessColors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vencido ? 'Modo de teste — encerrado' : 'Modo de teste — $daysLeft ${daysLeft == 1 ? 'dia restante' : 'dias restantes'}',
                  style: const TextStyle(color: AccessColors.orange, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Período de teste gratuito do Acertaí',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSubscribe,
            style: FilledButton.styleFrom(
              backgroundColor: AccessColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            child: const Text('Assinar'),
          ),
        ],
      ),
    );
  }
}
