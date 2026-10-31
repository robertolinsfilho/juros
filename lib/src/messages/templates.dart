import 'dart:convert';

import '../data/repository.dart';

/// Um tipo de mensagem de WhatsApp, com as variáveis que ele aceita.
class TemplateKind {
  const TemplateKind(this.id, this.label, this.variables, this.body);

  final String id;
  final String label;
  final List<String> variables;
  final String body;
}

const _line = '━━━━━━━━━━━━━━━━';

const templateKinds = <TemplateKind>[
  TemplateKind(
    'registrado',
    'Empréstimo Registrado',
    [
      'contrato_id',
      'data_contrato',
      'cliente_nome',
      'valor_principal',
      'taxa_juros',
      'total_juros',
      'total_pagar',
      'primeiro_vencimento',
      'lista_parcelas',
      'mora_explicacao',
      'assinatura',
    ],
    '📄 *EMPRÉSTIMO REGISTRADO*\n$_line\n\n'
        '📋 Contrato nº {{contrato_id}}\n'
        '📅 Fechado em {{data_contrato}}\n\n'
        '👤 *{{cliente_nome}}*\n\n'
        '💵 Valor emprestado: *{{valor_principal}}*\n'
        '📈 Taxa: *{{taxa_juros}}%*\n'
        '💰 Juros no total: *{{total_juros}}*\n'
        '🧾 Total a pagar: *{{total_pagar}}*\n'
        '📅 Primeiro vencimento: *{{primeiro_vencimento}}*\n\n'
        '📋 *Suas parcelas*\n{{lista_parcelas}}\n\n{{mora_explicacao}}\n\n{{assinatura}}',
  ),
  TemplateKind(
    'registrado_juros',
    'Empréstimo Registrado (Juros + capital no final)',
    [
      'contrato_id',
      'data_contrato',
      'cliente_nome',
      'valor_principal',
      'juros_mensal',
      'periodo',
      'periodo_do',
      'valor_quitar',
      'lista_parcelas',
      'mora_explicacao',
      'assinatura',
    ],
    '📄 *EMPRÉSTIMO REGISTRADO*\n$_line\n\n'
        '📋 Contrato nº {{contrato_id}}\n'
        '📅 Fechado em {{data_contrato}}\n\n'
        '👤 *{{cliente_nome}}*\n\n'
        '💵 Capital emprestado: *{{valor_principal}}*\n'
        '💰 Juros: *{{juros_mensal}}* por {{periodo}}\n'
        '🏁 Para quitar: *{{valor_quitar}}*\n\n'
        '📅 *Próximos vencimentos dos juros*\n{{lista_parcelas}}\n\n{{mora_explicacao}}\n\n{{assinatura}}',
  ),
  TemplateKind(
    'renegociado',
    'Contrato Renegociado',
    [
      'contrato_id',
      'contrato_anterior',
      'data_contrato',
      'cliente_nome',
      'divida_anterior',
      'bloco_acordo',
      'valor_principal',
      'taxa_juros',
      'total_juros',
      'total_pagar',
      'primeiro_vencimento',
      'lista_parcelas',
      'assinatura',
    ],
    '🔁 *CONTRATO RENEGOCIADO*\n$_line\n\n'
        '📋 Novo contrato nº {{contrato_id}}\n'
        '📄 Substitui o contrato nº {{contrato_anterior}}\n'
        '📅 Data: {{data_contrato}}\n\n'
        '👤 *{{cliente_nome}}*\n\n'
        '🧾 Dívida anterior: *{{divida_anterior}}*\n{{bloco_acordo}}\n'
        '💵 Novo valor: *{{valor_principal}}*\n'
        '📈 Taxa: *{{taxa_juros}}%*\n'
        '💰 Juros no total: *{{total_juros}}*\n'
        '🧾 Total a pagar: *{{total_pagar}}*\n'
        '📅 Primeiro vencimento: *{{primeiro_vencimento}}*\n\n'
        '📋 *Suas novas parcelas*\n{{lista_parcelas}}\n\n{{assinatura}}',
  ),
  TemplateKind(
    'renegociado_juros',
    'Contrato Renegociado (Juros + capital no final)',
    [
      'contrato_id',
      'contrato_anterior',
      'data_contrato',
      'cliente_nome',
      'divida_anterior',
      'bloco_acordo',
      'valor_principal',
      'juros_mensal',
      'bloco_primeira_parcela',
      'periodo',
      'periodo_do',
      'valor_quitar',
      'lista_parcelas',
      'assinatura',
    ],
    '🔁 *CONTRATO RENEGOCIADO*\n$_line\n\n'
        '📋 Novo contrato nº {{contrato_id}}\n'
        '📄 Substitui o contrato nº {{contrato_anterior}}\n'
        '📅 Data: {{data_contrato}}\n\n'
        '👤 *{{cliente_nome}}*\n\n'
        '🧾 Dívida anterior: *{{divida_anterior}}*\n{{bloco_acordo}}\n'
        '💵 Capital: *{{valor_principal}}*\n'
        '💰 Juros: *{{juros_mensal}}* por {{periodo}}\n'
        '{{bloco_primeira_parcela}}\n'
        '🏁 Para quitar: *{{valor_quitar}}*\n\n'
        '📅 *Próximos vencimentos dos juros*\n{{lista_parcelas}}\n\n{{assinatura}}',
  ),
  TemplateKind(
    'situacao',
    'Situação do Contrato',
    ['cliente_nome', 'bloco_status', 'bloco_progresso', 'bloco_proximo', 'lista_parcelas_status', 'mora_explicacao', 'assinatura'],
    'Olá, *{{cliente_nome}}*!\n$_line\n\n'
        '📊 *SITUAÇÃO DO SEU CONTRATO*\n\n'
        '{{bloco_status}}\n{{bloco_progresso}}\n{{bloco_proximo}}\n\n'
        '📋 *Parcelas*\n{{lista_parcelas_status}}\n\n{{assinatura}}\n\n{{mora_explicacao}}',
  ),
  TemplateKind(
    'pre_vencimento',
    'Pré-vencimento',
    [
      'cliente_nome',
      'parcela_valor',
      'valor_total',
      'parcela_numero',
      'total_parcelas',
      'parcela_vencimento',
      'progresso_bar',
      'bloco_atrasos',
      'parcelas_atrasadas_lista',
      'qtd_atrasadas',
      'total_atrasado',
      'saldo_devedor',
      'total_quitacao',
      'mora_explicacao',
      'assinatura',
    ],
    'Olá, *{{cliente_nome}}*! 👋\n$_line\n\n'
        '🔔 *LEMBRETE DE VENCIMENTO*\n\n'
        '💵 Valor: *{{parcela_valor}}*\n'
        '📊 Parcela {{parcela_numero}} de {{total_parcelas}}\n'
        '📅 Vence em: *{{parcela_vencimento}}*\n\n'
        '{{progresso_bar}}\n\n'
        'Se já pagou, é só desconsiderar este aviso.\n\n'
        '{{bloco_atrasos}}\n{{assinatura}}\n\n{{mora_explicacao}}',
  ),
  TemplateKind(
    'vencimento_hoje',
    'Vencimento Hoje',
    [
      'cliente_nome',
      'parcela_valor',
      'valor_total',
      'parcela_numero',
      'total_parcelas',
      'parcela_vencimento',
      'progresso_bar',
      'bloco_atrasos',
      'parcelas_atrasadas_lista',
      'qtd_atrasadas',
      'total_atrasado',
      'saldo_devedor',
      'total_quitacao',
      'mora_explicacao',
      'assinatura',
    ],
    'Olá, *{{cliente_nome}}*! 👋\n$_line\n\n'
        '📅 *VENCE HOJE*\n\n'
        '💵 Valor: *{{parcela_valor}}*\n'
        '📊 Parcela {{parcela_numero}} de {{total_parcelas}}\n'
        '📅 Vencimento: *hoje ({{parcela_vencimento}})*\n\n'
        '{{progresso_bar}}\n\n'
        'Pagando hoje você mantém tudo em dia.\n\n'
        '{{bloco_atrasos}}\n{{assinatura}}\n\n{{mora_explicacao}}',
  ),
  TemplateKind(
    'atrasado',
    'Atrasado (c/ mora)',
    [
      'cliente_nome',
      'parcela_valor',
      'parcela_numero',
      'total_parcelas',
      'parcela_vencimento',
      'dias_atraso',
      'mora_valor',
      'total_com_mora',
      'progresso_bar',
      'bloco_atrasos',
      'parcelas_atrasadas_lista',
      'qtd_atrasadas',
      'total_atrasado',
      'saldo_devedor',
      'total_quitacao',
      'mora_explicacao',
      'assinatura',
    ],
    'Olá, *{{cliente_nome}}*.\n$_line\n\n'
        '⚠️ *PARCELA EM ATRASO*\n\n'
        '💵 Valor: *{{parcela_valor}}*\n'
        '📊 Parcela {{parcela_numero}} de {{total_parcelas}}\n'
        '📅 Venceu em: *{{parcela_vencimento}}*\n'
        '🕐 Atraso: *{{dias_atraso}} dia(s)*\n'
        '💸 Mora: *{{mora_valor}}*\n'
        '💰 Total com mora: *{{total_com_mora}}*\n\n'
        '{{progresso_bar}}\n\n'
        'Vamos acertar? Quanto antes pagar, menos mora acumula.\n\n'
        '{{bloco_atrasos}}\n{{assinatura}}\n\n{{mora_explicacao}}',
  ),
  TemplateKind(
    'consolidada',
    'Cobrança Consolidada (vários contratos)',
    [
      'cliente_nome',
      'qtd_atrasadas',
      'qtd_contratos',
      'lista_contratos_atraso',
      'total_atrasado',
      'mora_texto',
      'total_regularizar',
      'mora_explicacao',
      'assinatura',
    ],
    'Olá, *{{cliente_nome}}*.\n$_line\n\n'
        '⚠️ *PARCELAS EM ATRASO ({{qtd_atrasadas}})*\n\n'
        '{{lista_contratos_atraso}}\n\n'
        '🧾 Total em atraso: *{{total_atrasado}}*\n{{mora_texto}}\n'
        '✅ Para regularizar tudo: *{{total_regularizar}}*\n\n'
        'Me responda por aqui para combinarmos o pagamento.\n\n{{assinatura}}\n\n{{mora_explicacao}}',
  ),
  TemplateKind(
    'aberto',
    'Empréstimo Aberto',
    [
      'cliente_nome',
      'parcela_valor',
      'periodo',
      'periodo_do',
      'parcela_vencimento',
      'capital_aberto',
      'mora_texto',
      'parcelas_atrasadas_lista',
      'qtd_atrasadas',
      'total_juros_aberto',
      'total_quitacao',
      'mora_explicacao',
      'assinatura',
    ],
    'Olá, *{{cliente_nome}}*! 👋\n$_line\n\n'
        '📅 *COBRANÇA DE JUROS*\n\n'
        '💵 Juros {{periodo_do}}: *{{parcela_valor}}*\n'
        '📅 Vencimento: *{{parcela_vencimento}}*\n{{mora_texto}}\n\n'
        '{{parcelas_atrasadas_lista}}\n'
        '💰 Capital em aberto: *{{capital_aberto}}*\n'
        '🧾 Juros em aberto: *{{total_juros_aberto}}*\n'
        '✅ Para quitar tudo: *{{total_quitacao}}*\n\n'
        'Obrigado por manter os pagamentos em dia.\n{{assinatura}}\n\n{{mora_explicacao}}',
  ),
  TemplateKind(
    'pagamento',
    'Confirmação de Pagamento',
    [
      'cliente_nome',
      'contrato_id',
      'valor_emprestimo',
      'data_pagamento',
      'lista_parcelas_status',
      'proximo_vencimento',
      'bloco_parcela',
      'bloco_progresso',
      'bloco_saldo',
      'bloco_saldo_quitacao',
      'assinatura',
    ],
    '✅ *PAGAMENTO RECEBIDO*\n$_line\n\n'
        '📋 Contrato nº {{contrato_id}}\n'
        '👤 Cliente: {{cliente_nome}}\n'
        '💰 Valor do empréstimo: {{valor_emprestimo}}\n'
        '{{bloco_parcela}}\n'
        '📅 Data: {{data_pagamento}}\n\n'
        '{{bloco_progresso}}'
        '📊 *Situação das parcelas*\n{{lista_parcelas_status}}\n\n'
        '{{bloco_saldo_quitacao}}'
        '📅 Próximo vencimento: {{proximo_vencimento}}\n\n{{assinatura}}',
  ),
];

TemplateKind kindById(String id) => templateKinds.firstWhere((kind) => kind.id == id, orElse: () => templateKinds.first);

class CustomTemplate {
  const CustomTemplate({required this.id, required this.kind, required this.name, required this.body});

  final String id;
  final String kind;
  final String name;
  final String body;

  Map<String, Object?> toJson() => {'id': id, 'kind': kind, 'name': name, 'body': body};

  static CustomTemplate fromJson(Map<String, dynamic> json) => CustomTemplate(
    id: json['id'] as String,
    kind: json['kind'] as String,
    name: json['name'] as String,
    body: json['body'] as String,
  );
}

class PixKeyEntry {
  const PixKeyEntry({required this.label, required this.key});

  final String label;
  final String key;

  String get title => label.isEmpty ? key : '$label · $key';
}

/// Monta o rodapé; campos vazios ficam de fora.
String composeSignature({String creditor = '', String company = '', String pix = ''}) {
  final lines = <String>[_line];
  if (creditor.trim().isNotEmpty) lines.add(creditor.trim());
  if (company.trim().isNotEmpty) lines.add(company.trim());
  if (pix.trim().isNotEmpty) lines.add('💳 PIX: ${pix.trim()}');
  return lines.join('\n');
}

/// Configuração de mensagens guardada na tabela de ajustes.
class MessageConfig {
  MessageConfig(this.repo);

  final Repo repo;

  String get creditor => repo.setting('creditor_name');
  bool get showCreditor => repo.setting('sig_show_creditor', '1') == '1';
  String get company => repo.setting('company_name');
  bool get showCompany => repo.setting('sig_show_company', '0') == '1';
  String get pix => repo.setting('pix_key');
  bool get showPix => repo.setting('sig_show_pix', '1') == '1';
  bool get fraction => repo.setting('sig_fraction', '0') == '1';

  List<PixKeyEntry> get pixKeys {
    final raw = repo.setting('pix_keys');
    if (raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          PixKeyEntry(label: (item as Map)['label'] as String, key: item['key'] as String),
      ];
    } catch (_) {
      return const [];
    }
  }

  void savePixKeys(List<PixKeyEntry> keys) {
    repo.setSetting('pix_keys', jsonEncode([for (final key in keys) {'label': key.label, 'key': key.key}]));
  }

  void saveSignature({
    required String creditor,
    required bool showCreditor,
    required String company,
    required bool showCompany,
    required String pix,
    required bool showPix,
    required bool fraction,
  }) {
    repo.setSetting('creditor_name', creditor.trim());
    repo.setSetting('sig_show_creditor', showCreditor ? '1' : '0');
    repo.setSetting('company_name', company.trim());
    repo.setSetting('sig_show_company', showCompany ? '1' : '0');
    repo.setSetting('pix_key', pix.trim());
    repo.setSetting('sig_show_pix', showPix ? '1' : '0');
    repo.setSetting('sig_fraction', fraction ? '1' : '0');
  }

  /// Texto do rodapé das mensagens. [pixOverride] é a chave escolhida no empréstimo.
  String signature({String pixOverride = ''}) {
    return composeSignature(
      creditor: showCreditor ? creditor : '',
      company: showCompany ? company : '',
      pix: showPix ? (pixOverride.isNotEmpty ? pixOverride : pix) : '',
    );
  }

  List<CustomTemplate> get customs {
    final raw = repo.setting('msg_custom');
    if (raw.isEmpty) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List<dynamic>) CustomTemplate.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  void saveCustoms(List<CustomTemplate> items) {
    repo.setSetting('msg_custom', jsonEncode([for (final item in items) item.toJson()]));
  }

  String activeCustomId(String kind) => repo.setting('msg_active_$kind');

  void setActiveCustom(String kind, String id) => repo.setSetting('msg_active_$kind', id);

  bool hasOverride(String kind) => repo.setting('msg_tpl_$kind').isNotEmpty;

  void saveOverride(String kind, String body) => repo.setSetting('msg_tpl_$kind', body);

  void resetOverride(String kind) => repo.setSetting('msg_tpl_$kind', '');

  /// Modelo em uso para o tipo: o personalizado ativo, o padrão editado ou o original.
  String bodyFor(String kind) {
    final active = activeCustomId(kind);
    if (active.isNotEmpty) {
      for (final custom in customs) {
        if (custom.id == active) return custom.body;
      }
    }
    final override = repo.setting('msg_tpl_$kind');
    return override.isNotEmpty ? override : kindById(kind).body;
  }
}

String renderTemplate(String body, Map<String, String> vars) {
  final text = body.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (match) => vars[match[1]] ?? '');
  return text.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// Exemplo usado nas pré-visualizações.
Map<String, String> sampleVariables(String signature) {
  return {
    'assinatura': signature,
    'cliente_nome': 'João Silva',
    'contrato_id': '128',
    'contrato_anterior': '97',
    'data_contrato': '05/03/2026',
    'valor_principal': 'R\$ 1.000,00',
    'taxa_juros': '10,00',
    'total_juros': 'R\$ 100,00',
    'total_pagar': 'R\$ 1.100,00',
    'primeiro_vencimento': '05/04/2026',
    'lista_parcelas': '1️⃣ ⏳ 05/04/2026 · R\$ 550,00\n2️⃣ ⏳ 05/05/2026 · R\$ 550,00',
    'juros_mensal': 'R\$ 100,00',
    'periodo': 'mês',
    'periodo_do': 'do mês',
    'valor_quitar': 'R\$ 1.000,00',
    'divida_anterior': 'R\$ 1.250,00',
    'bloco_acordo': '🤝 Desconto combinado: R\$ 50,00\n',
    'bloco_primeira_parcela': '📅 Primeiro vencimento: 05/04/2026',
    'bloco_status': '📋 Contrato nº 128\n💵 Emprestado: R\$ 1.000,00\n✅ Situação: em dia',
    'bloco_progresso': '▓▓▓░░░░░░░ 30%\n',
    'bloco_proximo': '📅 Próximo vencimento: 25/03/2026 · R\$ 500,00',
    'lista_parcelas_status': '1️⃣ ✅ 25/01/2026 · R\$ 500,00\n2️⃣ ✅ 25/02/2026 · R\$ 500,00\n3️⃣ ⏳ 25/03/2026 · R\$ 500,00',
    'parcela_valor': 'R\$ 500,00',
    'valor_total': 'R\$ 5.000,00',
    'parcela_numero': '3',
    'total_parcelas': '10',
    'parcela_vencimento': '25/03/2026',
    'progresso_bar': '▓▓▓░░░░░░░ 30%',
    'bloco_atrasos': '📌 *Outras parcelas em atraso (1):*\n• 15/03/2026 · R\$ 250,00 (5 dias)\n\n'
        '🧾 Total em atraso: R\$ 250,00\n💰 Saldo devedor: R\$ 1.500,00\n✅ Para quitar: R\$ 1.525,00\n',
    'parcelas_atrasadas_lista': '⚠️ 15/03/2026 · R\$ 250,00 (5 dias)\n',
    'qtd_atrasadas': '2',
    'qtd_contratos': '2',
    'total_atrasado': 'R\$ 250,00',
    'saldo_devedor': 'R\$ 1.500,00',
    'total_quitacao': 'R\$ 1.525,00',
    'dias_atraso': '5',
    'mora_valor': 'R\$ 25,00',
    'mora_texto': '💸 Mora: R\$ 25,00',
    'mora_explicacao':
        '*Se atrasar:* a cada dia de atraso, cada parcela em aberto soma 1% ao dia sobre o valor dela (mora).',
    'total_com_mora': 'R\$ 525,00',
    'lista_contratos_atraso': '📋 *Contrato nº 128*\n• 15/03/2026 · R\$ 250,00 (5 dias)\n📋 *Contrato nº 131*\n• 10/03/2026 · R\$ 300,00 (10 dias)',
    'total_regularizar': 'R\$ 575,00',
    'capital_aberto': 'R\$ 1.000,00',
    'total_juros_aberto': 'R\$ 200,00',
    'valor_emprestimo': 'R\$ 5.000,00',
    'data_pagamento': '25/03/2026',
    'bloco_parcela': '💵 Parcela 3 de 10: R\$ 500,00',
    'bloco_saldo': '💰 Saldo devedor: R\$ 1.500,00\n',
    'bloco_saldo_quitacao': '💰 Saldo devedor: R\$ 1.500,00\n✅ Para quitar: R\$ 1.525,00\n',
    'proximo_vencimento': '25/04/2026',
  };
}
