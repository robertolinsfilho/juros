import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../auth/login_store.dart';
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
  bool remember = true;
  String? error;

  @override
  void initState() {
    super.initState();
    final saved = readSavedLogin();
    remember = saved.remember;
    if (saved.user.isNotEmpty) {
      username.text = saved.user;
      password.text = saved.password;
    }
    username.addListener(persist);
    password.addListener(persist);
  }

  void persist() {
    if (!remember) return;
    writeSavedLogin(username.text.trim(), password.text, remember: true);
  }

  void setRemember(bool value) {
    setState(() => remember = value);
    if (value) {
      persist();
      return;
    }
    writeSavedLogin('', '', remember: false);
  }

  @override
  void dispose() {
    username.removeListener(persist);
    password.removeListener(persist);
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
      if (!mounted) return;
      if (caught.pending) {
        final login = username.text.trim();
        final secret = password.text;
        await showEmailPendingDialog(
          context,
          email: caught.email.isEmpty ? 'o e-mail cadastrado' : caught.email,
          onResend: () async {
            try {
              await widget.auth.resendSignup(username: login, password: secret);
              return null;
            } on AuthException catch (again) {
              return again.message;
            }
          },
        );
      } else {
        setState(() => error = caught.message);
      }
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
                        AutofillGroup(
                          child: Column(
                            children: [
                              TextField(
                                controller: username,
                                autofocus: true,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(labelText: 'Usuário'),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: password,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) => submit(),
                                decoration: const InputDecoration(labelText: 'Senha'),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: busy ? null : () => setRemember(!remember),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: remember,
                                  onChanged: busy ? null : (value) => setRemember(value ?? false),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text('Lembrar neste aparelho'),
                                        SizedBox(height: 2),
                                        Text(
                                          'Na próxima entrada, usuário e senha já aparecem preenchidos.',
                                          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
