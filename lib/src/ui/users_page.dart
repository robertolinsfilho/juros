import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../theme.dart';
import 'widgets.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.auth, required this.token, required this.selfId});

  final AuthApi auth;
  final String token;
  final int selfId;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<List<SessionUser>> future = widget.auth.users(widget.token);

  void reload() => setState(() => future = widget.auth.users(widget.token));

  Future<void> create() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _UserDialog(auth: widget.auth, token: widget.token),
    );
    if (created == true) reload();
  }

  Future<void> toggle(SessionUser user) async {
    try {
      await widget.auth.setActive(widget.token, user.id, !user.active);
      reload();
    } on AuthException catch (error) {
      if (mounted) showError(context, error.message);
    }
  }

  Future<void> role(SessionUser user) async {
    try {
      await widget.auth.setRole(widget.token, user.id, user.isAdmin ? 'comum' : 'admin');
      reload();
    } on AuthException catch (error) {
      if (mounted) showError(context, error.message);
    }
  }

  Future<void> access(SessionUser user) async {
    final days = await showDialog<int>(
      context: context,
      builder: (context) => _AccessDialog(user: user),
    );
    if (days == null) return;
    try {
      await widget.auth.setAccess(widget.token, user.id, days: days, plan: days > 0 ? 'mensal' : '');
      if (mounted) showError(context, days > 0 ? 'Acesso liberado por $days dias.' : 'Acesso encerrado.');
      reload();
    } on AuthException catch (error) {
      if (mounted) showError(context, error.message);
    }
  }

  Future<void> password(SessionUser user) async {
    final next = await askPassword(context, 'Nova senha de ${user.name}');
    if (next == null) return;
    try {
      await widget.auth.setPassword(widget.token, user.id, next);
      if (mounted) showError(context, 'Senha atualizada.');
    } on AuthException catch (error) {
      if (mounted) showError(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: pagePadding(context),
      children: [
        PageHeader(
          title: 'Usuários',
          subtitle: 'Administradores gerenciam o acesso. Os demais usam a operação.',
          actions: [
            FilledButton.icon(onPressed: create, icon: const Icon(Icons.person_add_alt), label: const Text('Novo usuário')),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<SessionUser>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              final message = snapshot.error is AuthException ? snapshot.error.toString() : 'Não foi possível carregar os usuários.';
              return Panel(child: Text(message));
            }
            final users = snapshot.data ?? const <SessionUser>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (users.any((user) => user.access.status != 'assinante')) ...[
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pedidos de assinatura', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        FutureBuilder(
                          future: widget.auth.requests(widget.token),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Text('Carregando...', style: TextStyle(color: AppColors.muted));
                            final items = snapshot.data!;
                            if (items.isEmpty) {
                              return const Text('Nenhum pedido ainda.', style: TextStyle(color: AppColors.muted));
                            }
                            return Column(
                              children: [
                                for (final item in items.take(6))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${item.name} · ${item.planLabel}',
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        Text(
                                          item.status == 'pendente' ? 'pendente' : 'concluído',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: item.status == 'pendente' ? AppColors.amber : AppColors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final user in users)
                        RecordTile(
                          title: user.name,
                          subtitle:
                              '${user.username}${user.email.isEmpty ? "" : " · ${user.email}"} · ${user.roleLabel} · '
                              '${user.access.label}${user.access.daysLeft > 0 ? ' (${user.access.daysLeft}d)' : ''}'
                              '${user.active ? '' : ' · desativado'}',
                          actions: [
                            TextButton(onPressed: () => access(user), child: const Text('Acesso')),
                            TextButton(
                              onPressed: () => role(user),
                              child: Text(user.isAdmin ? 'Tornar comum' : 'Tornar admin'),
                            ),
                            if (user.id != widget.selfId)
                              TextButton(onPressed: () => password(user), child: const Text('Senha')),
                            TextButton(
                              onPressed: () => toggle(user),
                              child: Text(user.active ? 'Desativar' : 'Reativar'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({required this.auth, required this.token});

  final AuthApi auth;
  final String token;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final username = TextEditingController();
  final name = TextEditingController();
  final password = TextEditingController();
  String role = 'comum';
  String? error;
  bool busy = false;

  @override
  void dispose() {
    username.dispose();
    name.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.auth.createUser(
        widget.token,
        username: username.text,
        name: name.text,
        password: password.text,
        role: role,
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (caught) {
      if (mounted) setState(() => error = caught.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Novo usuário'),
      content: SizedBox(
        width: dialogWidth(context, 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 16),
              TextField(controller: username, decoration: const InputDecoration(labelText: 'Usuário para login')),
              const SizedBox(height: 16),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Nível de acesso'),
                items: const [
                  DropdownMenuItem(value: 'comum', child: Text('Usuário comum')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                ],
                onChanged: (value) => setState(() => role = value ?? 'comum'),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(error!, style: const TextStyle(color: AppColors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: busy ? null : save, child: const Text('Cadastrar')),
      ],
    );
  }
}

class _AccessDialog extends StatefulWidget {
  const _AccessDialog({required this.user});

  final SessionUser user;

  @override
  State<_AccessDialog> createState() => _AccessDialogState();
}

class _AccessDialogState extends State<_AccessDialog> {
  int days = 31;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Acesso de ${widget.user.name}'),
      content: SizedBox(
        width: dialogWidth(context, 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hoje: ${widget.user.access.label}'
              '${widget.user.access.daysLeft > 0 ? ' · ${widget.user.access.daysLeft} dia(s)' : ''}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in const [(31, '1 mês'), (92, '3 meses'), (365, '1 ano'), (0, 'Encerrar')])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: days == option.$1,
                    onSelected: (_) => setState(() => days = option.$1),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              days == 0
                  ? 'O acesso será encerrado na hora e a pessoa volta a ver a tela de planos.'
                  : 'Libera $days dias de acesso a partir de hoje.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, days), child: const Text('Confirmar')),
      ],
    );
  }
}

Future<String?> askPassword(BuildContext context, String title) {  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nova senha'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Salvar'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
