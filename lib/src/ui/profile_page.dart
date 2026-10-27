import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../theme.dart';
import 'widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.auth,
    required this.token,
    required this.user,
    required this.onUpdated,
  });

  final AuthApi auth;
  final String token;
  final SessionUser user;
  final ValueChanged<SessionUser> onUpdated;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final name = TextEditingController(text: widget.user.name);
  final currentPassword = TextEditingController();
  final nextPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  bool savingName = false;
  bool savingPassword = false;
  String? nameError;
  String? nameOk;
  String? passwordError;
  String? passwordOk;

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.name != widget.user.name && name.text == oldWidget.user.name) {
      name.text = widget.user.name;
    }
  }

  @override
  void dispose() {
    name.dispose();
    currentPassword.dispose();
    nextPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> saveName() async {
    setState(() {
      savingName = true;
      nameError = null;
      nameOk = null;
    });
    try {
      final updated = await widget.auth.updateProfile(widget.token, name: name.text);
      widget.onUpdated(updated);
      if (mounted) setState(() => nameOk = 'Nome atualizado.');
    } on AuthException catch (error) {
      if (mounted) setState(() => nameError = error.message);
    } finally {
      if (mounted) setState(() => savingName = false);
    }
  }

  Future<void> savePassword() async {
    setState(() {
      savingPassword = true;
      passwordError = null;
      passwordOk = null;
    });
    if (nextPassword.text != confirmPassword.text) {
      setState(() {
        savingPassword = false;
        passwordError = 'A confirmação não é igual à nova senha.';
      });
      return;
    }
    try {
      await widget.auth.setPassword(
        widget.token,
        widget.user.id,
        nextPassword.text,
        current: currentPassword.text,
      );
      currentPassword.clear();
      nextPassword.clear();
      confirmPassword.clear();
      if (mounted) setState(() => passwordOk = 'Senha atualizada.');
    } on AuthException catch (error) {
      if (mounted) setState(() => passwordError = error.message);
    } finally {
      if (mounted) setState(() => savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: pagePadding(context),
      children: [
        const PageHeader(
          title: 'Perfil',
          subtitle: 'Seus dados de acesso',
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 12),
              Text('Usuário: ${widget.user.username}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 4),
              Text('Nível: ${widget.user.roleLabel}', style: const TextStyle(color: AppColors.muted)),
              if (nameError != null) ...[
                const SizedBox(height: 12),
                Text(nameError!, style: const TextStyle(color: AppColors.red)),
              ],
              if (nameOk != null) ...[
                const SizedBox(height: 12),
                Text(nameOk!, style: const TextStyle(color: AppColors.green)),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: savingName ? null : saveName,
                  child: Text(savingName ? 'Salvando...' : 'Salvar nome'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Trocar senha', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: currentPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha atual'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nextPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nova senha'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmar nova senha'),
                onSubmitted: (_) => savePassword(),
              ),
              if (passwordError != null) ...[
                const SizedBox(height: 12),
                Text(passwordError!, style: const TextStyle(color: AppColors.red)),
              ],
              if (passwordOk != null) ...[
                const SizedBox(height: 12),
                Text(passwordOk!, style: const TextStyle(color: AppColors.green)),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: savingPassword ? null : savePassword,
                  child: Text(savingPassword ? 'Salvando...' : 'Trocar senha'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
