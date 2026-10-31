import 'package:flutter/material.dart';

import '../domain/schedule.dart';
import '../format.dart';
import '../theme.dart';

/// Bloco de mora do formulário de empréstimo: tipo, taxa e texto do WhatsApp.
class LateFeeFields extends StatelessWidget {
  const LateFeeFields({
    super.key,
    required this.mode,
    required this.onMode,
    required this.percent,
    required this.daily,
    required this.fixed,
    required this.explain,
    required this.onExplain,
    required this.explainText,
    required this.onExplainEdited,
    required this.onValuesChanged,
  });

  final String mode;
  final ValueChanged<String> onMode;
  final TextEditingController percent;
  final TextEditingController daily;
  final TextEditingController fixed;
  final bool explain;
  final ValueChanged<bool> onExplain;
  final TextEditingController explainText;
  final VoidCallback onExplainEdited;
  final VoidCallback onValuesChanged;

  bool get _hasMora => mode != 'sem_mora';
  bool get _asksPercent => mode == 'percentual_dia' || mode == 'taxa_unica_percentual';
  bool get _asksDaily => mode == 'valor_fixo';
  bool get _asksFixed => mode == 'taxa_unica_percentual';

  String get _hint {
    return switch (mode) {
      'percentual_dia' =>
        'Sugerido: 1% ao dia (30% ao mês).\n'
            'Calculada sobre o valor de cada parcela atrasada. Se duas parcelas atrasarem, cada uma acumula a sua mora.',
      'valor_fixo' => 'Valor cobrado por dia em cada parcela atrasada. Se duas atrasarem, cada uma acumula o seu.',
      'taxa_unica_percentual' =>
        'A taxa única entra uma vez no atraso. O percentual soma todo dia sobre o valor daquela parcela.',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(mode),
          initialValue: mode,
          decoration: const InputDecoration(labelText: 'Juros por atraso (mora)'),
          items: const [
            DropdownMenuItem(value: 'sem_mora', child: Text('Sem mora')),
            DropdownMenuItem(value: 'percentual_dia', child: Text('% ao dia')),
            DropdownMenuItem(value: 'valor_fixo', child: Text('Valor fixo por dia')),
            DropdownMenuItem(value: 'taxa_unica_percentual', child: Text('Taxa única + % ao dia')),
          ],
          onChanged: (next) => onMode(next ?? mode),
        ),
        if (_asksPercent) ...[
          const SizedBox(height: 16),
          TextField(
            controller: percent,
            onChanged: (_) => onValuesChanged(),
            decoration: const InputDecoration(labelText: 'Taxa (% ao dia)'),
            keyboardType: TextInputType.number,
          ),
        ],
        if (_asksDaily) ...[
          const SizedBox(height: 16),
          TextField(
            controller: daily,
            onChanged: (_) => onValuesChanged(),
            decoration: const InputDecoration(labelText: 'Valor por dia'),
            keyboardType: TextInputType.number,
          ),
        ],
        if (_asksFixed) ...[
          const SizedBox(height: 16),
          TextField(
            controller: fixed,
            onChanged: (_) => onValuesChanged(),
            decoration: const InputDecoration(labelText: 'Taxa única'),
            keyboardType: TextInputType.number,
          ),
        ],
        if (_hasMora) ...[
          if (_hint.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_hint, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
          ],
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: explain,
            onChanged: (next) => onExplain(next ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Enviar explicação da mora no WhatsApp'),
            subtitle: const Text(
              'Este texto vai no fim das mensagens de cobrança e da situação do empréstimo, '
              'sempre que você enviar uma delas pelo WhatsApp. Serve para o cliente saber, '
              'antes de atrasar, quanto vai pagar a mais.',
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
            ),
          ),
          if (explain) ...[
            TextField(
              controller: explainText,
              onChanged: (_) => onExplainEdited(),
              decoration: const InputDecoration(labelText: 'Texto da explicação'),
              maxLines: 3,
            ),
          ],
        ],
      ],
    );
  }
}

void fillLateExplanation(
  TextEditingController controller, {
  required String mode,
  required TextEditingController percent,
  required TextEditingController daily,
  required TextEditingController fixed,
}) {
  controller.text = defaultLateExplanation(
    mode: mode,
    percentBps: parsePercentBps(percent.text) ?? 0,
    dailyCents: parseMoney(daily.text) ?? 0,
    fixedCents: parseMoney(fixed.text) ?? 0,
  );
}
