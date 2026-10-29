import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../messages/templates.dart';
import '../theme.dart';
import 'message_dialog.dart';
import 'widgets.dart';

class _PixRow {
  _PixRow(String label, String key)
    : label = TextEditingController(text: label),
      key = TextEditingController(text: key);

  final TextEditingController label;
  final TextEditingController key;

  void dispose() {
    label.dispose();
    key.dispose();
  }
}

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key, required this.repo, required this.onChanged});

  final Repo repo;
  final VoidCallback onChanged;

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  late final MessageConfig config = MessageConfig(widget.repo);
  late final creditor = TextEditingController(text: config.creditor);
  late final company = TextEditingController(text: config.company);
  late final pix = TextEditingController(text: config.pix);
  late bool showCreditor = config.showCreditor;
  late bool showCompany = config.showCompany;
  late bool showPix = config.showPix;
  late bool fraction = config.fraction;
  late final List<_PixRow> extraPix = [for (final entry in config.pixKeys) _PixRow(entry.label, entry.key)];
  bool pixOpen = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [creditor, company, pix]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    creditor.dispose();
    company.dispose();
    pix.dispose();
    for (final row in extraPix) {
      row.dispose();
    }
    super.dispose();
  }

  String get previewSignature => composeSignature(
    creditor: showCreditor ? creditor.text : '',
    company: showCompany ? company.text : '',
    pix: showPix ? pix.text : '',
  );

  void saveSignature() {
    config.saveSignature(
      creditor: creditor.text,
      showCreditor: showCreditor,
      company: company.text,
      showCompany: showCompany,
      pix: pix.text,
      showPix: showPix,
      fraction: fraction,
    );
    config.savePixKeys([
      for (final row in extraPix)
        if (row.key.text.trim().isNotEmpty) PixKeyEntry(label: row.label.text.trim(), key: row.key.text.trim()),
    ]);
    widget.onChanged();
    setState(() {});
    showError(context, 'Assinatura salva.');
  }

  Widget toggleField(String label, TextEditingController controller, bool value, ValueChanged<bool> onToggle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: TextField(controller: controller, decoration: InputDecoration(labelText: label))),
        const SizedBox(width: 8),
        Column(
          children: [
            const Text('Mostrar', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            Switch(value: value, onChanged: (next) => setState(() => onToggle(next))),
          ],
        ),
      ],
    );
  }

  Widget signatureCard() {
    final example = fraction ? '1/12' : '1️⃣';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assinatura das mensagens', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Aparece no final de toda mensagem, no lugar de {{assinatura}}.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          const Text('Identificação', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          toggleField('Seu nome', creditor, showCreditor, (value) => showCreditor = value),
          const SizedBox(height: 8),
          toggleField('Empresa', company, showCompany, (value) => showCompany = value),
          const SizedBox(height: 16),
          const Text('Pagamento', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          toggleField('Chave PIX', pix, showPix, (value) => showPix = value),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => setState(() => pixOpen = !pixOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(pixOpen ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    extraPix.isEmpty ? 'Outras chaves PIX' : 'Outras chaves PIX (${extraPix.length})',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          if (pixOpen) ...[
            for (var index = 0; index < extraPix.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: extraPix[index].label,
                        decoration: const InputDecoration(labelText: 'Rótulo'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: extraPix[index].key,
                        decoration: const InputDecoration(labelText: 'Nova chave PIX'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remover',
                      onPressed: () => setState(() => extraPix.removeAt(index).dispose()),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => extraPix.add(_PixRow('', ''))),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar chave'),
              ),
            ),
            const Text(
              'Ao criar um empréstimo você pode escolher qual chave aparece na mensagem.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Lista de parcelas', style: TextStyle(fontWeight: FontWeight.w600)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mostrar parcela como 1/12'),
                    Text(
                      'Exemplo: $example ⏳ 05/04/2026 · R\$ 550,00',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(value: fraction, onChanged: (value) => setState(() => fraction = value)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Pré-visualização', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          WhatsAppText(previewSignature),
          const SizedBox(height: 16),
          FilledButton(onPressed: saveSignature, child: const Text('Salvar assinatura')),
        ],
      ),
    );
  }

  String sampleOf(String body) {
    final vars = sampleVariables(previewSignature);
    if (fraction) {
      vars['lista_parcelas'] = vars['lista_parcelas']!.replaceAll('1️⃣', '1/2').replaceAll('2️⃣', '2/2');
    }
    return renderTemplate(body, vars);
  }

  Future<void> editDefault(TemplateKind kind) async {
    final result = await showTemplateEditor(
      context,
      signature: previewSignature,
      kind: kind.id,
      lockKind: true,
      showName: false,
      title: 'Editar ${kind.label}',
      body: config.hasOverride(kind.id) ? widget.repo.setting('msg_tpl_${kind.id}') : kind.body,
    );
    if (result == null) return;
    config.saveOverride(kind.id, result.body);
    config.setActiveCustom(kind.id, '');
    widget.onChanged();
    setState(() {});
  }

  Future<void> createCustom() async {
    final result = await showTemplateEditor(
      context,
      signature: previewSignature,
      kind: templateKinds.first.id,
      lockKind: false,
      showName: true,
      title: 'Novo template',
      body: templateKinds.first.body,
    );
    if (result == null) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    config.saveCustoms([
      ...config.customs,
      CustomTemplate(id: id, kind: result.kind, name: result.name, body: result.body),
    ]);
    config.setActiveCustom(result.kind, id);
    widget.onChanged();
    setState(() {});
  }

  Future<void> editCustom(CustomTemplate custom) async {
    final result = await showTemplateEditor(
      context,
      signature: previewSignature,
      kind: custom.kind,
      lockKind: false,
      showName: true,
      title: 'Editar template',
      name: custom.name,
      body: custom.body,
    );
    if (result == null) return;
    if (result.kind != custom.kind && config.activeCustomId(custom.kind) == custom.id) {
      config.setActiveCustom(custom.kind, '');
    }
    config.saveCustoms([
      for (final item in config.customs)
        if (item.id == custom.id)
          CustomTemplate(id: custom.id, kind: result.kind, name: result.name, body: result.body)
        else
          item,
    ]);
    widget.onChanged();
    setState(() {});
  }

  Future<void> deleteCustom(CustomTemplate custom) async {
    final ok = await confirmAction(context, 'Excluir template', 'Excluir "${custom.name}"?');
    if (!ok) return;
    if (config.activeCustomId(custom.kind) == custom.id) config.setActiveCustom(custom.kind, '');
    config.saveCustoms([for (final item in config.customs) if (item.id != custom.id) item]);
    widget.onChanged();
    setState(() {});
  }

  void toggleCustom(CustomTemplate custom, bool on) {
    config.setActiveCustom(custom.kind, on ? custom.id : '');
    widget.onChanged();
    setState(() {});
  }

  Future<void> restoreDefault(TemplateKind kind) async {
    final ok = await confirmAction(context, 'Restaurar padrão', 'Voltar "${kind.label}" para o texto original?');
    if (!ok) return;
    config.resetOverride(kind.id);
    config.setActiveCustom(kind.id, '');
    widget.onChanged();
    setState(() {});
  }

  Widget kindCard(TemplateKind kind) {
    final customs = [for (final item in config.customs) if (item.kind == kind.id) item];
    final activeId = config.activeCustomId(kind.id);
    final body = config.bodyFor(kind.id);
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final edited = config.hasOverride(kind.id);
    final usingCustom = customs.any((item) => item.id == activeId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey('kind-${kind.id}'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Row(
              children: [
                Flexible(child: Text(kind.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                if (usingCustom || edited) ...[
                  const SizedBox(width: 8),
                  Text(
                    usingCustom ? 'Personalizado' : 'Editado',
                    style: const TextStyle(color: AppColors.green, fontSize: 12),
                  ),
                ],
              ],
            ),
            subtitle: Text(flat, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
            children: [
              WhatsAppText(sampleOf(body)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(onPressed: () => editDefault(kind), child: const Text('Editar')),
                  if (edited || usingCustom)
                    OutlinedButton(onPressed: () => restoreDefault(kind), child: const Text('Restaurar padrão')),
                ],
              ),
              if (customs.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Meus templates', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                for (final custom in customs)
                  Row(
                    children: [
                      Expanded(child: Text(custom.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const Text('Em uso', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      Switch(value: activeId == custom.id, onChanged: (on) => toggleCustom(custom, on)),
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: () => editCustom(custom),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Excluir',
                        onPressed: () => deleteCustom(custom),
                        icon: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        signatureCard(),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text('Templates WhatsApp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            FilledButton.icon(
              onPressed: createCustom,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo template'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Escolha o texto de cada tipo de mensagem. Use variáveis como {{cliente_nome}} e {{assinatura}}.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        for (final kind in templateKinds) kindCard(kind),
      ],
    );
  }
}

class TemplateEdit {
  const TemplateEdit({required this.kind, required this.name, required this.body});

  final String kind;
  final String name;
  final String body;
}

Future<TemplateEdit?> showTemplateEditor(
  BuildContext context, {
  required String signature,
  required String kind,
  required bool lockKind,
  required bool showName,
  required String title,
  required String body,
  String name = '',
}) {
  return showDialog<TemplateEdit>(
    context: context,
    builder: (context) => _TemplateEditor(
      signature: signature,
      kind: kind,
      lockKind: lockKind,
      showName: showName,
      title: title,
      body: body,
      name: name,
    ),
  );
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({
    required this.signature,
    required this.kind,
    required this.lockKind,
    required this.showName,
    required this.title,
    required this.body,
    required this.name,
  });

  final String signature;
  final String kind;
  final bool lockKind;
  final bool showName;
  final String title;
  final String body;
  final String name;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late String kind = widget.kind;
  late final body = TextEditingController(text: widget.body);
  late final name = TextEditingController(text: widget.name);

  @override
  void dispose() {
    body.dispose();
    name.dispose();
    super.dispose();
  }

  void insert(String variable) {
    final token = '{{$variable}}';
    final selection = body.selection;
    final start = selection.isValid ? selection.start : body.text.length;
    final end = selection.isValid ? selection.end : body.text.length;
    body.value = TextEditingValue(
      text: body.text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    setState(() {});
  }

  void submit() {
    if (widget.showName && name.text.trim().isEmpty) {
      showError(context, 'Dê um nome ao template.');
      return;
    }
    if (body.text.trim().isEmpty) {
      showError(context, 'A mensagem não pode ficar vazia.');
      return;
    }
    Navigator.pop(context, TemplateEdit(kind: kind, name: name.text.trim(), body: body.text));
  }

  @override
  Widget build(BuildContext context) {
    final current = kindById(kind);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showName) ...[
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do template')),
                const SizedBox(height: 16),
              ],
              if (!widget.lockKind) ...[
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [
                    for (final item in templateKinds) DropdownMenuItem(value: item.id, child: Text(item.label)),
                  ],
                  onChanged: (value) => setState(() => kind = value ?? kind),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: body,
                minLines: 8,
                maxLines: 14,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Mensagem', alignLabelWithHint: true),
              ),
              const SizedBox(height: 8),
              const Text('Variáveis (toque para inserir)', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final variable in current.variables)
                    ActionChip(label: Text('{{$variable}}'), onPressed: () => insert(variable)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Pré-visualização', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              WhatsAppText(renderTemplate(body.text, sampleVariables(widget.signature))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: submit, child: Text(widget.showName && widget.title.startsWith('Novo') ? 'Criar' : 'Atualizar')),
      ],
    );
  }
}
