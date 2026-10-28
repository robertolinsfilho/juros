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
    this.onSubscribe,
  });

  final AuthApi auth;
  final String token;
  final SessionUser user;
  final ValueChanged<SessionUser> onUpdated;
  final VoidCallback? onSubscribe;

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
  bool cancelling = false;
  String? nameError;
  String? nameOk;
  String? passwordError;
  String? passwordOk;
  String? cancelError;

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

  bool get canCancel => widget.user.access.subscriber && widget.user.access.plan != 'cortesia';

  Future<void> cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar assinatura'),
        content: const Text(
          'A assinatura encerra agora e os dias restantes deixam de valer. '
          'O valor já pago no Mercado Pago não é estornado por aqui.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Manter assinatura')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            child: const Text('Cancelar assinatura'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      cancelling = true;
      cancelError = null;
    });
    try {
      final updated = await widget.auth.cancelSubscription(widget.token);
      widget.onUpdated(updated);
    } on AuthException catch (error) {
      if (mounted) setState(() => cancelError = error.message);
    } finally {
      if (mounted) setState(() => cancelling = false);
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
              Text('Assinatura', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                widget.user.access.subscriber
                    ? 'Assinatura ativa · ${widget.user.access.daysLeft} dia(s) restantes'
                    : widget.user.access.trial
                    ? 'Teste gratuito · ${widget.user.access.daysText}'
                    : 'Teste encerrado',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: widget.onSubscribe,
                      child: const Text('Ver planos'),
                    ),
                    if (canCancel)
                      OutlinedButton(
                        onPressed: cancelling ? null : cancelSubscription,
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                        child: Text(cancelling ? 'Cancelando...' : 'Cancelar assinatura'),
                      ),
                  ],
                ),
              ),
              if (cancelError != null) ...[
                const SizedBox(height: 12),
                Text(cancelError!, style: const TextStyle(color: AppColors.red)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 12),
              Text('Usuário: ${widget.user.username}', style: const TextStyle(color: AppColors.muted)),
              if (widget.user.email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('E-mail: ${widget.user.email}', style: const TextStyle(color: AppColors.muted)),
              ],
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
