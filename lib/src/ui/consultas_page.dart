import 'dart:async';
import 'dart:convert';

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
        padding: const EdgeInsets.all(16),
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
            right: 16,
            top: 32,
            child: Icon(face.icon, size: 108, color: Colors.white.withValues(alpha: 0.16)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      const SizedBox(width: 8),
                      Text(face.badge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(face.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 88),
                  child: Text(face.summary, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.3)),
                ),
                const SizedBox(height: 16),
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
                    const SizedBox(width: 16),
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
          padding: const EdgeInsets.symmetric(horizontal: Space.compact, vertical: Space.compact),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_faceOf(product).title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(fmtMoney(product.cents), style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                for (final bullet in product.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
          padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                if (current.done) ResultView(value: current.result) else if (current.error.isNotEmpty) Text(current.error),
                if (current.status == 'consultando' || (current.status == 'paga' && current.error.isEmpty))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Aguardando a confirmação e o retorno dos dados.', style: TextStyle(color: AppColors.muted)),
                  ),
                if (current.status == 'paga') ...[
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: busy ? null : retry, child: const Text('Buscar de novo')),
                ],
              ],
              if (message != null) ...[
                const SizedBox(height: 16),
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
          padding: const EdgeInsets.all(24),
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
    final root = _prepare(value);
    final score = _firstScore(root);
    final cards = _cards(root);
    if (score == null && cards.isEmpty) {
      return const Text('A consulta não trouxe registros.', style: TextStyle(color: AppColors.muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (score != null) _ScoreBanner(score: score.$1, note: score.$2),
        ...cards,
      ],
    );
  }
}

class _ScoreBanner extends StatelessWidget {
  const _ScoreBanner({required this.score, this.note});

  final String score;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Text(score, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.green)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Score', style: TextStyle(fontWeight: FontWeight.w700)),
                if (note != null && note!.isNotEmpty) Text(note!, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: const TextStyle(color: AppColors.muted, height: 1.35)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35))),
        ],
      ),
    );
  }
}

const _labels = {
  'credcadastral': 'Crédito',
  'dadosCadastrais': 'Dados cadastrais',
  'dados_receita_federal': 'Receita Federal',
  'identificacao_pessoa_fisica': 'Identificação',
  'informacoes_da_empresa': 'Empresa',
  'nome': 'Nome',
  'nomeCompleto': 'Nome',
  'nomeMae': 'Nome da mãe',
  'nomePai': 'Nome do pai',
  'cpf': 'CPF',
  'cnpj': 'CNPJ',
  'rg': 'RG',
  'dataNascimento': 'Nascimento',
  'data_nascimento': 'Nascimento',
  'sexo': 'Sexo',
  'estadoCivil': 'Estado civil',
  'situacaoCPF': 'Situação do CPF',
  'situacao': 'Situação',
  'cep': 'CEP',
  'bairro': 'Bairro',
  'cidade': 'Cidade',
  'uf': 'UF',
  'endereco': 'Endereço',
  'enderecos': 'Endereços',
  'logradouro': 'Logradouro',
  'numero': 'Número',
  'complemento': 'Complemento',
  'email': 'E-mail',
  'emails': 'E-mails',
  'telefone': 'Telefone',
  'telefones': 'Telefones',
  'celular': 'Celular',
  'somente_telefone': 'Telefones',
  'somente_endereco': 'Endereços',
  'score': 'Score',
  'scores': 'Score',
  'texto': 'Descrição',
  'probabilidade': 'Probabilidade',
  'classificacao': 'Classificação',
  'classe': 'Classe',
  'risco': 'Risco',
  'protestos': 'Protestos',
  'protesto_sintetico': 'Protestos',
  'pend_financeiras': 'Pendências',
  'pendencias': 'Pendências',
  'valor': 'Valor',
  'data': 'Data',
  'dataOcorrencia': 'Data',
  'cartorio': 'Cartório',
  'dadosCartorio': 'Cartório',
  'quantidade': 'Quantidade',
  'origem': 'Origem',
  'contrato': 'Contrato',
  'modalidade': 'Modalidade',
  'credor': 'Credor',
  'empresa': 'Empresa',
  'razaoSocial': 'Razão social',
  'nomeFantasia': 'Nome fantasia',
  'quadro_societario': 'Sócios',
  'acoes_civeis': 'Ações',
  'acoesCiveis': 'Ações',
  'chequesSemFundo': 'Cheques sem fundo',
  'ch_sem_fundos_bacen': 'Cheques sem fundo',
  'scrBacen': 'BACEN',
  'titulos': 'Títulos',
  'pdf': 'Relatório',
  'descricao': 'Descrição',
  'mensagem': 'Mensagem',
  'observacao': 'Observação',
};

const _hidden = {
  'status_retorno',
  'statusRetorno',
  'providerId',
  'provedorReserva',
  'prioridade',
  'homolog',
  'api_limit_for',
  'balance',
  'tax',
  'valor_consulta',
};

const _unwrapKeys = {
  'dados',
  'data',
  'response',
  'resultado',
  'retorno',
  'results',
  'consultaCredito',
  'acertaEssencialPositivo',
  'acertaEssencial',
  'dossieCreditoPf',
  'dossieCreditoPj',
};

const _flatLabels = {
  'cadastral': 'Identificação',
  'dsgenero': 'Gênero',
  'dsstatuscpf': 'Situação do CPF',
  'dtnascimento': 'Nascimento',
  'idade': 'Idade',
  'nmcompleto': 'Nome',
  'nmmae': 'Nome da mãe',
  'nmpai': 'Nome do pai',
  'nrcpf': 'CPF',
  'nrcnpj': 'CNPJ',
  'sggenero': 'Gênero',
  'sgstatuscpf': 'Situação do CPF',
  'dtultimavisualizacao': 'Última atualização',
  'nrtelefone': 'Telefone',
  'nrddd': 'DDD',
  'nrcep': 'CEP',
  'dslogradouro': 'Logradouro',
  'dscomplemento': 'Complemento',
  'nmbairro': 'Bairro',
  'nmcidade': 'Cidade',
  'sguf': 'UF',
  'dsemail': 'E-mail',
};

const _dropFields = {
  'cdordem',
  'nmprimeiro',
  'nmmeio',
  'nmultimo',
};

const _wordLabels = {
  'genero': 'Gênero',
  'mae': 'mãe',
  'numero': 'Número',
  'endereco': 'Endereço',
  'situacao': 'Situação',
  'descricao': 'Descrição',
  'codigo': 'Código',
  'atualizacao': 'Atualização',
  'visualizacao': 'Visualização',
  'nascimento': 'Nascimento',
  'cpf': 'CPF',
  'cnpj': 'CNPJ',
  'cep': 'CEP',
  'uf': 'UF',
  'ddd': 'DDD',
  'rg': 'RG',
};

const _scoreKeys = {'score', 'scorepositivo', 'pontuacao', 'scoring'};

const _noteKeys = {'texto', 'descricao', 'classificacao', 'classe', 'risco', 'mensagem'};

Object? _decode(Object? value) {
  if (value is! String) return value;
  final text = value.trim();
  if (!text.startsWith('{') && !text.startsWith('[')) return value;
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map || decoded is List) return decoded;
  } catch (_) {}
  return value;
}

bool _blank(Object? value) {
  if (value == null) return true;
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return true;
    final tree = _decode(value);
    if (tree is Map || tree is List) return _blank(tree);
    return false;
  }
  if (value is List) return value.every(_blank);
  if (value is Map) return _entries(value).isEmpty;
  return false;
}

String _flat(String key) => key.toLowerCase().replaceAll('_', '');

bool _skipField(Map map, String key) {
  if (_hidden.contains(key)) return true;
  final flat = _flat(key);
  if (_dropFields.contains(flat)) return true;
  if (flat.startsWith('sg')) {
    final stem = flat.substring(2);
    if (map.keys.any((other) => _flat(other.toString()) == 'ds$stem')) return true;
  }
  if (flat == 'nome' && map.keys.any((other) => _flat(other.toString()) == 'nmcompleto')) return true;
  return false;
}

List<MapEntry> _entries(Map map) {
  return [
    for (final entry in map.entries)
      if (!_skipField(map, entry.key.toString()) && !_blank(entry.value)) entry,
  ];
}

List<MapEntry> _ordered(Map map) {
  const preferred = [
    'nmcompleto',
    'nomecompleto',
    'nrcpf',
    'cpf',
    'dtnascimento',
    'datanascimento',
    'idade',
    'dsgenero',
    'sexo',
    'dsstatuscpf',
    'situacaocpf',
    'nmmae',
    'nomemae',
    'nmpai',
  ];
  final entries = _entries(map);
  final indexed = [for (var i = 0; i < entries.length; i++) MapEntry(i, entries[i])];
  indexed.sort((a, b) {
    final rankA = preferred.indexOf(_flat(a.value.key.toString()));
    final rankB = preferred.indexOf(_flat(b.value.key.toString()));
    final byRank = (rankA < 0 ? 100 : rankA).compareTo(rankB < 0 ? 100 : rankB);
    if (byRank != 0) return byRank;
    return a.key.compareTo(b.key);
  });
  return [for (final item in indexed) item.value];
}

String _scalarTitle(Map map) {
  final flats = map.keys.map((key) => _flat(key.toString())).toSet();
  if (flats.contains('nmcompleto') || flats.contains('nrcpf') || flats.contains('dtnascimento')) {
    return 'Identificação';
  }
  return 'Dados';
}

Object? _prepare(Object? value) {
  var current = _decode(value);
  for (var step = 0; step < 8; step++) {
    if (current is List && current.length == 1) {
      final only = _decode(current.first);
      if (only is Map || only is List) {
        current = only;
        continue;
      }
    }
    if (current is Map) {
      final entries = _entries(current);
      if (entries.length == 1 && _unwrapKeys.contains(entries.first.key.toString())) {
        final inner = _decode(entries.first.value);
        if (inner is Map || inner is List) {
          current = inner;
          continue;
        }
      }
    }
    break;
  }
  return current;
}

(String, String?)? _firstScore(Object? value, [int depth = 0]) {
  if (value == null || depth > 6) return null;
  final current = _decode(value);
  if (current is Map) {
    for (final entry in current.entries) {
      if (_scoreKeys.contains(entry.key.toString().toLowerCase())) {
        final found = _scoreValue(entry.value);
        if (found != null) return found;
      }
    }
    for (final entry in current.entries) {
      final found = _firstScore(entry.value, depth + 1);
      if (found != null) return found;
    }
  } else if (current is List) {
    for (final item in current) {
      final found = _firstScore(item, depth + 1);
      if (found != null) return found;
    }
  }
  return null;
}

(String, String?)? _scoreValue(Object? value) {
  if (value is num) return (_plainNumber(value), null);
  if (value is String && num.tryParse(value.trim()) != null) return (value.trim(), null);
  if (value is! Map) return null;
  Object? number;
  String? note;
  for (final entry in value.entries) {
    final key = entry.key.toString().toLowerCase();
    if (number == null && (_scoreKeys.contains(key) || key == 'valor' || key == 'pontos')) {
      if (entry.value is num || entry.value is String) number = entry.value;
    }
    if (note == null && _noteKeys.contains(key) && entry.value is String && (entry.value as String).trim().isNotEmpty) {
      note = (entry.value as String).trim();
    }
  }
  if (number is num) return (_plainNumber(number), note);
  if (number is String && number.trim().isNotEmpty) return (number.trim(), note);
  return null;
}

String _plainNumber(num value) {
  if (value is double && value == value.roundToDouble()) return '${value.round()}';
  return '$value';
}

List<Widget> _cards(Object? value) {
  final current = _decode(value);
  if (current is List) {
    final body = _nodes(current);
    if (body.isEmpty) return const [];
    return [_ResultCard(title: 'Registros', children: body)];
  }
  if (current is Map) {
    final scalars = <Widget>[];
    final blocks = <Widget>[];
    for (final entry in _ordered(current)) {
      final key = entry.key.toString();
      final inner = _decode(entry.value);
      if (_isPdf(key, inner)) {
        blocks.add(_pdfButton(inner as String));
        continue;
      }
      if (inner is Map || inner is List) {
        final children = _nodes(inner);
        if (children.isEmpty) continue;
        blocks.add(_ResultCard(title: _label(key), children: children));
      } else if (inner != null && !_blank(inner)) {
        scalars.add(_FieldRow(label: _label(key), value: _show(key, inner)));
      }
    }
    return [
      if (scalars.isNotEmpty) _ResultCard(title: _scalarTitle(current), children: scalars),
      ...blocks,
    ];
  }
  if (current == null || _blank(current)) return const [];
  return [
    _ResultCard(title: 'Dados', children: [_FieldRow(label: 'Resultado', value: _show('resultado', current))]),
  ];
}

List<Widget> _nodes(Object? value) {
  final current = _decode(value);
  if (current is List) {
    final visible = current.where((item) => !_blank(item)).toList();
    final shown = visible.take(20).toList();
    final widgets = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      final item = _decode(shown[i]);
      if (i > 0) widgets.add(const Divider(height: 16));
      if (item is Map) {
        final title = _recordTitle(item, i);
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ));
        widgets.addAll(_mapFields(item, skipTitle: title));
      } else if (item is List) {
        widgets.addAll(_nodes(item));
      } else if (item != null) {
        widgets.add(Text(_show('item', item), style: const TextStyle(fontWeight: FontWeight.w600)));
      }
    }
    if (visible.length > shown.length) {
      widgets.add(Text('e mais ${visible.length - shown.length}', style: const TextStyle(color: AppColors.muted)));
    }
    return widgets;
  }
  if (current is Map) return _mapFields(current);
  if (current == null || _blank(current)) return const [];
  return [Text(_show('item', current), style: const TextStyle(fontWeight: FontWeight.w600))];
}

List<Widget> _mapFields(Map map, {String? skipTitle}) {
  final widgets = <Widget>[];
  for (final entry in _ordered(map)) {
    final key = entry.key.toString();
    final inner = _decode(entry.value);
    if (skipTitle != null && inner is String && inner.trim() == skipTitle) continue;
    if (_isPdf(key, inner)) {
      widgets.add(Align(alignment: Alignment.centerLeft, child: _pdfButton(inner as String)));
      continue;
    }
    if (inner is Map || inner is List) {
      final children = _nodes(inner);
      if (children.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(_label(key), style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700)),
        ),
      );
      widgets.addAll(children);
    } else if (inner != null && !_blank(inner)) {
      widgets.add(_FieldRow(label: _label(key), value: _show(key, inner)));
    }
  }
  return widgets;
}

String _recordTitle(Map map, int index) {
  for (final entry in map.entries) {
    final flat = _flat(entry.key.toString());
    if (flat != 'nmcompleto' && flat != 'nomecompleto' && flat != 'razaosocial' && flat != 'cartorio') continue;
    if (entry.value is String && (entry.value as String).trim().isNotEmpty) return (entry.value as String).trim();
  }
  for (final key in ['nome', 'nomeFantasia', 'empresa', 'credor', 'descricao']) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return 'Registro ${index + 1}';
}

bool _isPdf(String key, Object? value) {
  if (value is! String) return false;
  final text = value.trim();
  if (!text.startsWith('https://') && !text.startsWith('http://')) return false;
  final norm = key.toLowerCase();
  return norm.contains('pdf') || text.toLowerCase().contains('.pdf');
}

Widget _pdfButton(String url) {
  final uri = Uri.tryParse(url.trim());
  return TextButton(
    onPressed: uri == null ? null : () => openExternal(uri),
    child: const Text('Abrir PDF'),
  );
}

String _label(String key) {
  final known = _flatLabels[_flat(key)] ?? _labels[key];
  if (known != null) return known;
  final rest = _stripPrefix(key);
  final words = rest
      .replaceAllMapped(RegExp(r'([a-zá-ú])([A-Z])'), (match) => '${match[1]} ${match[2]}')
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(_word)
      .toList();
  if (words.isEmpty) return key;
  return words.join(' ');
}

String _stripPrefix(String key) {
  final snake = RegExp(r'^(ds|dt|nm|nr|sg|cd|vl|qt|st|tp)_(.+)$', caseSensitive: false).firstMatch(key);
  if (snake != null) return snake.group(2)!;
  final camel = RegExp(r'^(ds|dt|nm|nr|sg|cd|vl|qt|st|tp)([A-Z].+)$').firstMatch(key);
  if (camel != null) return camel.group(2)!;
  return key;
}

String _word(String word) {
  final known = _wordLabels[word.toLowerCase()];
  if (known != null) {
    if (known == known.toUpperCase() || known.startsWith(known[0].toUpperCase())) return known;
    return known[0].toUpperCase() + known.substring(1);
  }
  final lower = word.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

String _show(String key, Object value) {
  if (value is bool) return value ? 'Sim' : 'Não';
  final flat = _flat(key);
  if (value is num && _isMoney(key)) return fmtMoney((value * 100).round());
  if (value is num) {
    final digits = _plainNumber(value);
    return _document(flat, digits) ?? digits;
  }
  final text = value.toString().trim();
  if (_isMoney(key)) {
    final cents = _moneyCents(text);
    if (cents != null) return fmtMoney(cents);
  }
  final digits = text.replaceAll(RegExp(r'\D'), '');
  final document = _document(flat, digits);
  if (document != null) return document;
  if (flat.contains('cep') && digits.length == 8) return '${digits.substring(0, 5)}-${digits.substring(5)}';
  if (_isPhone(flat) && (digits.length == 10 || digits.length == 11)) return _phone(digits);
  if (flat.contains('genero') && text.length == 1) {
    final code = text.toUpperCase();
    if (code == 'M') return 'Masculino';
    if (code == 'F') return 'Feminino';
  }
  final date = _date(flat, text);
  if (date != null) return date;
  return text;
}

String? _document(String flat, String digits) {
  if (flat.contains('cpf') && digits.length == 11) return _maskDocument(digits);
  if (flat.contains('cnpj') && digits.length == 14) return _maskDocument(digits);
  return null;
}

bool _isMoney(String key) {
  final norm = key.toLowerCase();
  return norm.contains('valor') || norm.contains('quantia');
}

bool _isPhone(String key) {
  return key.contains('telefone') || key.contains('celular') || key.contains('fone');
}

int? _moneyCents(String text) {
  final normalized = text.contains(',') ? text.replaceAll('.', '').replaceAll(',', '.') : text;
  final parsed = double.tryParse(normalized);
  if (parsed == null) return null;
  return (parsed * 100).round();
}

String? _date(String key, String text) {
  if (!key.startsWith('dt') && !key.contains('nascimento') && !key.contains('data') && !key.contains('date')) return null;
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (iso != null) return '${iso[3]}/${iso[2]}/${iso[1]}';
  final compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(text);
  if (compact != null) return '${compact[3]}/${compact[2]}/${compact[1]}';
  return null;
}

String _phone(String digits) {
  if (digits.length == 11) {
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
  }
  return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
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
