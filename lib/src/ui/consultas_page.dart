import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../consultas.dart';
import '../format.dart';
import '../links.dart';
import '../theme.dart';
import 'widgets.dart';

class ConsultasPage extends StatefulWidget {
  const ConsultasPage({super.key, required this.auth, required this.token});

  final AuthApi auth;
  final String token;

  @override
  State<ConsultasPage> createState() => _ConsultasPageState();
}

class _ConsultasPageState extends State<ConsultasPage> {
  ConsultaBoard? board;
  String? error;
  bool loading = true;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await widget.auth.consultas(widget.token);
      if (!mounted) return;
      setState(() {
        board = next;
        loading = false;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        this.error = error.message;
        loading = false;
      });
    }
  }

  Future<void> openProduct(ConsultaProduct product) async {
    final current = board;
    if (current == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => ConsultaDialog(
        auth: widget.auth,
        token: widget.token,
        product: product,
        provider: current.provider,
      ),
    );
    if (mounted) await load();
  }

  Future<void> openRecord(ConsultaRecord record) async {
    try {
      final fresh = await widget.auth.consulta(widget.token, record.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => ConsultaResultDialog(record: fresh),
      );
      if (mounted) await load();
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = board;
    return ListView(
      padding: pagePadding(context),
      children: [
        const PageHeader(
          title: 'Consultas',
          subtitle: 'Pague cada consulta no Mercado Pago e o resultado fica aqui.',
        ),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(error!, style: const TextStyle(color: AppColors.red)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: load, child: const Text('Tentar de novo')),
        ],
        if (current != null && !current.provider) ...[
          const _Notice(
            'O cadastro do fornecedor já existe. O pagamento de cada consulta abre quando o saldo e o token estiverem no servidor.',
          ),
          const SizedBox(height: 16),
        ],
        if (current != null) ...[
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Consultas'),
                selected: tab == 0,
                selectedColor: AppColors.green,
                labelStyle: TextStyle(color: tab == 0 ? AppColors.greenInk : AppColors.text),
                onSelected: (_) => setState(() => tab = 0),
              ),
              ChoiceChip(
                label: const Text('Histórico'),
                selected: tab == 1,
                selectedColor: AppColors.green,
                labelStyle: TextStyle(color: tab == 1 ? AppColors.greenInk : AppColors.text),
                onSelected: (_) => setState(() => tab = 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tab == 0) _Catalog(products: current.products, onOpen: openProduct) else _History(records: current.history, onOpen: openRecord),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: const TextStyle(color: AppColors.text)),
      ),
    );
  }
}

class _Catalog extends StatelessWidget {
  const _Catalog({required this.products, required this.onOpen});

  final List<ConsultaProduct> products;
  final ValueChanged<ConsultaProduct> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 980 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final product in products)
              SizedBox(
                width: width,
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(product.summary, style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 12),
                      Text(fmtMoney(product.cents), style: const TextStyle(color: AppColors.green, fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(onPressed: () => _showExample(context, product), child: const Text('O que vem')),
                          FilledButton(onPressed: () => onOpen(product), child: const Text('Consultar')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showExample(BuildContext context, ConsultaProduct product) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: dialogWidth(context, 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(fmtMoney(product.cents), style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                for (final bullet in product.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $bullet'),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.records, required this.onOpen});

  final List<ConsultaRecord> records;
  final ValueChanged<ConsultaRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Text('Nenhuma consulta realizada ainda.', style: TextStyle(color: AppColors.muted));
    }
    return Column(
      children: [
        for (final record in records) ...[
          Panel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(record.title),
              subtitle: Text('${_maskDocument(record.document)} · ${record.statusLabel}'),
              trailing: Text(fmtMoney(record.amountCents), style: const TextStyle(color: AppColors.green)),
              onTap: () => onOpen(record),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class ConsultaDialog extends StatefulWidget {
  const ConsultaDialog({
    super.key,
    required this.auth,
    required this.token,
    required this.product,
    required this.provider,
  });

  final AuthApi auth;
  final String token;
  final ConsultaProduct product;
  final bool provider;

  @override
  State<ConsultaDialog> createState() => _ConsultaDialogState();
}

class _ConsultaDialogState extends State<ConsultaDialog> {
  late String searchType = widget.product.inputs.first.id;
  final document = TextEditingController();
  Timer? timer;
  String? message;
  bool busy = false;
  ConsultaRecord? record;

  @override
  void dispose() {
    timer?.cancel();
    document.dispose();
    super.dispose();
  }

  ConsultaInput get input => widget.product.inputs.firstWhere((item) => item.id == searchType);

  Future<void> pay() async {
    if (!widget.provider) {
      setState(() => message = 'As consultas ainda não estão ligadas ao fornecedor. O pagamento não foi aberto.');
      return;
    }
    final value = document.text.trim();
    if (value.isEmpty) {
      setState(() => message = 'Preencha ${input.label.toLowerCase()}.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    await openWhenReady(() async {
      try {
        final started = await widget.auth.startConsulta(
          widget.token,
          slug: widget.product.slug,
          document: value,
          searchType: searchType,
        );
        if (!mounted) return null;
        if (started.checkoutUrl.isEmpty || started.id == 0) {
          setState(() => message = 'O Mercado Pago não devolveu o checkout.');
          return null;
        }
        setState(() => message = 'Checkout aberto. Conclua o pagamento na outra aba.');
        watch(started.id);
        return Uri.tryParse(started.checkoutUrl);
      } on AuthException catch (error) {
        if (mounted) setState(() => message = error.message);
        return null;
      } finally {
        if (mounted) setState(() => busy = false);
      }
    });
  }

  void watch(int id) {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh(id));
  }

  Future<void> refresh(int id) async {
    try {
      final next = await widget.auth.consulta(widget.token, id);
      if (!mounted) return;
      setState(() => record = next);
      if (next.done || next.status == 'falha' || (next.status == 'paga' && next.error.isNotEmpty)) {
        timer?.cancel();
      }
    } catch (_) {}
  }

  Future<void> retry() async {
    final current = record;
    if (current == null) return;
    setState(() => busy = true);
    try {
      final next = await widget.auth.retryConsulta(widget.token, current.id);
      if (!mounted) return;
      setState(() => record = next);
      if (!next.done) watch(next.id);
    } on AuthException catch (error) {
      if (mounted) setState(() => message = error.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = record;
    return Dialog(
      child: SizedBox(
        width: dialogWidth(context, 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.product.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(fmtMoney(widget.product.cents), style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (current == null) ...[
                if (widget.product.inputs.length > 1)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final item in widget.product.inputs)
                        ChoiceChip(
                          label: Text(item.label),
                          selected: searchType == item.id,
                          selectedColor: AppColors.green,
                          labelStyle: TextStyle(color: searchType == item.id ? AppColors.greenInk : AppColors.text),
                          onSelected: busy ? null : (_) => setState(() => searchType = item.id),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: document,
                  keyboardType: searchType == 'email' ? TextInputType.emailAddress : TextInputType.number,
                  decoration: InputDecoration(labelText: input.label),
                ),
                const SizedBox(height: 8),
                const Text(
                  'O Mercado Pago cobra este valor agora. O resultado aparece nesta tela.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : pay,
                  child: Text(busy ? 'Abrindo...' : 'Pagar e consultar'),
                ),
              ] else ...[
                Text(current.statusLabel, style: TextStyle(color: _statusColor(current.status), fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (current.done) ResultView(value: current.result) else if (current.error.isNotEmpty) Text(current.error),
                if (current.status == 'consultando' || (current.status == 'paga' && current.error.isEmpty))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Aguardando a confirmação e o retorno dos dados.', style: TextStyle(color: AppColors.muted)),
                  ),
                if (current.status == 'paga') ...[
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: busy ? null : retry, child: const Text('Buscar de novo')),
                ],
              ],
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(message!, style: const TextStyle(color: AppColors.amber)),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConsultaResultDialog extends StatelessWidget {
  const ConsultaResultDialog({super.key, required this.record});

  final ConsultaRecord record;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: dialogWidth(context, 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(record.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${record.statusLabel} · ${_maskDocument(record.document)}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              if (record.done) ResultView(value: record.result) else Text(record.error.isEmpty ? record.statusLabel : record.error),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.value});

  final Object? value;

  @override
  Widget build(BuildContext context) {
    final blocks = _blocks(value, 0);
    if (blocks.isEmpty) {
      return const Text('A consulta não trouxe registros.', style: TextStyle(color: AppColors.muted));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }
}

const _labels = {
  'credcadastral': 'Crédito',
  'dados_receita_federal': 'Receita Federal',
  'identificacao_pessoa_fisica': 'Identificação',
  'informacoes_da_empresa': 'Empresa',
  'pend_financeiras': 'Pendências',
  'protestos': 'Protestos',
  'protesto_sintetico': 'Protestos',
  'scores': 'Score',
  'score': 'Score',
  'emails': 'E-mails',
  'somente_telefone': 'Telefones',
  'somente_endereco': 'Endereços',
  'ch_sem_fundos_bacen': 'Cheques sem fundo',
  'acoes_civeis': 'Ações',
  'quadro_societario': 'Sócios',
  'scrBacen': 'BACEN',
  'titulos': 'Títulos',
  'dadosCartorio': 'Cartório',
  'pdf': 'Relatório',
};

const _hidden = {
  'status_retorno',
  'statusRetorno',
  'providerId',
  'provedorReserva',
  'prioridade',
};

List<Widget> _blocks(Object? value, int depth) {
  if (value == null || depth > 5) return const [];
  if (value is Map) {
    final children = <Widget>[];
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (_hidden.contains(key)) continue;
      final inner = entry.value;
      if (inner == null || inner == '' || inner is List && inner.isEmpty || inner is Map && inner.isEmpty) continue;
      if (key == 'pdf' && inner is String && inner.startsWith('https://')) {
        children.add(
          TextButton(
            onPressed: () => openExternal(Uri.parse(inner)),
            child: const Text('Abrir PDF'),
          ),
        );
        continue;
      }
      final title = _labels[key] ?? _human(key);
      final nested = _blocks(inner, depth + 1);
      if (nested.isEmpty && inner is! String && inner is! num && inner is! bool) continue;
      children.add(
        Padding(
          padding: EdgeInsets.only(left: depth * 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
              if (inner is String || inner is num || inner is bool) Text('$inner') else ...nested,
            ],
          ),
        ),
      );
    }
    return children;
  }
  if (value is List) {
    final shown = value.take(12);
    return [
      for (final item in shown) ..._blocks(item, depth + 1),
      if (value.length > 12)
        Text('e mais ${value.length - 12}', style: const TextStyle(color: AppColors.muted)),
    ];
  }
  return [Text('$value')];
}

String _human(String key) {
  final words = key.replaceAll('_', ' ').trim();
  if (words.isEmpty) return key;
  return words[0].toUpperCase() + words.substring(1);
}

String _maskDocument(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits == value) {
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
  }
  if (digits.length == 14 && digits == value) {
    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12)}';
  }
  return value;
}

Color _statusColor(String status) {
  return switch (status) {
    'concluida' => AppColors.green,
    'falha' => AppColors.red,
    'aguardando' => AppColors.amber,
    _ => AppColors.blue,
  };
}
