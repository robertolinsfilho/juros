import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../theme.dart';
import 'brand.dart';
import 'widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth, required this.onSuccess, this.onBack, this.onSignup});

  final AuthApi auth;
  final VoidCallback? onBack;
  final VoidCallback? onSignup;
  final void Function(SessionUser user, String token) onSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.auth.login(username.text, password.text);
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
                  const Center(child: BrandLockup(width: 260)),
                  const SizedBox(height: 8),
                  const Text(
                    'Controle de empréstimos, parcelas e recebimentos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
                    ),
                    child: const Text(
                      '3 dias grátis ao criar a conta',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Entrar', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        const Text(
                          'Acesso apenas para usuários cadastrados.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: username,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(labelText: 'Usuário'),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => submit(),
                          decoration: const InputDecoration(labelText: 'Senha'),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          Text(error!, style: const TextStyle(color: AppColors.red)),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          child: Text(busy ? 'Entrando...' : 'Entrar'),
                        ),
                        if (widget.onSignup != null)
                          TextButton(
                            onPressed: widget.onSignup,
                            child: const Text('Criar conta grátis por 3 dias'),
                          ),
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
