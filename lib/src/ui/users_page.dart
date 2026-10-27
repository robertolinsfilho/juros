import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../theme.dart';
import 'widgets.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.auth, required this.token});

  final AuthApi auth;
  final String token;

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
            return Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final user in users)
                    RecordTile(
                      title: user.name,
                      subtitle: '${user.username} · ${user.roleLabel}${user.active ? '' : ' · desativado'}',
                      actions: [
                        TextButton(
                          onPressed: () => role(user),
                          child: Text(user.isAdmin ? 'Tornar comum' : 'Tornar admin'),
                        ),
                        TextButton(onPressed: () => password(user), child: const Text('Senha')),
                        TextButton(
                          onPressed: () => toggle(user),
                          child: Text(user.active ? 'Desativar' : 'Reativar'),
                        ),
                      ],
                    ),
                ],
              ),
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
              const SizedBox(height: 12),
              TextField(controller: username, decoration: const InputDecoration(labelText: 'Usuário para login')),
              const SizedBox(height: 12),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
              const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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

Future<String?> askPassword(BuildContext context, String title) {
  final controller = TextEditingController();
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
