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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Marketplace de Consultas', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Selecione o tipo de consulta desejado', style: TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
            if (current != null)
              TextButton(
                onPressed: () => setState(() => tab = tab == 0 ? 1 : 0),
                child: Text(tab == 0 ? 'Histórico' : 'Marketplace'),
              ),
          ],
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
        if (current != null)
          if (tab == 0)
            _Catalog(products: current.products, onOpen: openProduct)
          else
            _History(records: current.history, onOpen: openRecord),
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

class _Face {
  const _Face({
    required this.title,
    required this.summary,
    required this.badge,
    required this.colors,
    required this.icon,
  });

  final String title;
  final String summary;
  final String badge;
  final List<Color> colors;
  final IconData icon;
}

const _faces = <String, _Face>{
  'localizador': _Face(
    title: 'Localizador',
    summary: 'Encontre pessoas por nome, telefone e e-mail em todo o Brasil',
    badge: 'CPF',
    colors: [Color(0xFF1B6EAD), Color(0xFF0E3C68)],
    icon: Icons.location_on_outlined,
  ),
  'dossie': _Face(
    title: 'Detective',
    summary: 'Dossiê completo com dados cadastrais, endereços, telefones, veículos e mais',
    badge: 'CPF',
    colors: [Color(0xFFC56A14), Color(0xFF8A4510)],
    icon: Icons.manage_search_outlined,
  ),
  'protestos': _Face(
    title: 'Protestos',
    summary: 'Consulte protestos ativos em cartórios de todo o Brasil',
    badge: 'CPF / CNPJ',
    colors: [Color(0xFFB23B4A), Color(0xFF6E2430)],
    icon: Icons.gps_fixed,
  ),
  'rating': _Face(
    title: 'Rating de Crédito',
    summary: 'Score de risco e probabilidade de inadimplência em segundos',
    badge: 'CPF / CNPJ',
    colors: [Color(0xFF1B7A45), Color(0xFF0E4A30)],
    icon: Icons.bar_chart,
  ),
  'cadastro': _Face(
    title: 'Cadastro Plus',
    summary: 'Dados cadastrais, endereços, telefones e vínculos atualizados',
    badge: 'CPF / CNPJ',
    colors: [Color(0xFF0F6A4A), Color(0xFF0A3A30)],
    icon: Icons.fact_check_outlined,
  ),
  'essencial': _Face(
    title: 'Acerta Essencial Positivo',
    summary: 'Score Serasa, histórico e indicadores positivos de crédito',
    badge: 'CPF',
    colors: [Color(0xFF1A5278), Color(0xFF102C46)],
    icon: Icons.track_changes,
  ),
  'bacen': _Face(
    title: 'Resumo BACEN',
    summary: 'Responsabilidade no SCR, modalidades e instituições',
    badge: 'CPF / CNPJ',
    colors: [Color(0xFF0E6A78), Color(0xFF0A3A46)],
    icon: Icons.account_balance_outlined,
  ),
};

_Face _faceOf(ConsultaProduct product) {
  return _faces[product.slug] ??
      _Face(
        title: product.title,
        summary: product.summary,
        badge: product.inputs.length > 1 ? 'CPF / CNPJ' : 'CPF',
        colors: const [Color(0xFF1A5278), Color(0xFF102C46)],
        icon: Icons.manage_search_outlined,
      );
}

class _ConsultaCard extends StatelessWidget {
  const _ConsultaCard({required this.product, required this.onOpen, required this.onExample});

  final ConsultaProduct product;
  final VoidCallback onOpen;
  final VoidCallback onExample;

  @override
  Widget build(BuildContext context) {
    final face = _faceOf(product);
    return Container(
      constraints: const BoxConstraints(minHeight: 188),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: face.colors),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 28,
            child: Icon(face.icon, size: 108, color: Colors.white.withValues(alpha: 0.16)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(face.badge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(face.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 88),
                  child: Text(face.summary, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.3)),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A PARTIR DE',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 10, letterSpacing: 0.6, fontWeight: FontWeight.w700),
                        ),
                        Text(fmtMoney(product.cents), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        _Pill(label: 'Exemplo de consulta', onTap: onExample, dark: true),
                        _Pill(
                          label: 'Consultar',
                          onTap: onOpen,
                          trailing: const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.trailing, this.dark = false});

  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? Colors.black.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
            ],
          ),
        ),
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
        final columns = constraints.maxWidth > 860 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final product in products)
              SizedBox(width: width, child: _ConsultaCard(product: product, onOpen: () => onOpen(product), onExample: () => _showExample(context, product))),
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
                Text(_faceOf(product).title, style: Theme.of(context).textTheme.titleLarge),
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
              Text(_faceOf(widget.product).title, style: Theme.of(context).textTheme.titleLarge),
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
