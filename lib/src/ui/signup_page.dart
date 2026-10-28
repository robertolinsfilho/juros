import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../theme.dart';
import 'brand.dart';
import 'widgets.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.auth, required this.onSuccess, this.onBack, this.onLogin});

  final AuthApi auth;
  final void Function(SessionUser user, String token) onSuccess;
  final VoidCallback? onBack;
  final VoidCallback? onLogin;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    username.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    final login = username.text.trim().toLowerCase();
    final mail = email.text.trim().toLowerCase();
    if (name.text.trim().isEmpty) {
      setState(() => error = 'Informe o seu nome.');
      return;
    }
    if (!RegExp(r'^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$').hasMatch(mail)) {
      setState(() => error = 'Informe um e-mail válido.');
      return;
    }
    if (!RegExp(r'^[a-z0-9._]{3,32}$').hasMatch(login)) {
      setState(() => error = 'Usuário: 3 a 32 letras, números, ponto ou _.');
      return;
    }
    if (password.text.length < 6) {
      setState(() => error = 'A senha precisa ter pelo menos 6 caracteres.');
      return;
    }
    if (password.text != confirm.text) {
      setState(() => error = 'A confirmação da senha não confere.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.auth.signup(name: name.text, username: login, email: mail, password: password.text);
      if (!mounted) return;
      widget.onSuccess(result.user, result.token);
    } on AuthException catch (caught) {
      if (mounted) setState(() => error = caught.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: pagePadding(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Voltar ao início'),
                      ),
                    ),
                  const Center(child: BrandLockup(width: 220)),
                  const SizedBox(height: 12),
                  const Text(
                    '3 dias grátis. Sem cartão.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Criar conta grátis', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        const Text(
                          'A conta entra no teste de 3 dias. Depois aparece o aviso para assinar.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: name,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Seu nome'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(labelText: 'E-mail'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: username,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(labelText: 'Usuário para entrar'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Senha'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirm,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => submit(),
                          decoration: const InputDecoration(labelText: 'Confirmar senha'),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(error!, style: const TextStyle(color: AppColors.red)),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          child: Text(busy ? 'Criando...' : 'Criar conta grátis por 3 dias'),
                        ),
                        if (widget.onLogin != null) ...[
                          const SizedBox(height: 8),
                          TextButton(onPressed: widget.onLogin, child: const Text('Já tenho conta')),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
