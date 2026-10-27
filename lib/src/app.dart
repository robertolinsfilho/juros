import 'package:flutter/material.dart';

import 'auth/auth_api.dart';
import 'data/repository.dart';
import 'theme.dart';
import 'ui/cash_page.dart';
import 'ui/clients_page.dart';
import 'ui/collections_page.dart';
import 'ui/dashboard_page.dart';
import 'ui/loans_page.dart';
import 'ui/login_page.dart';
import 'ui/reports_page.dart';
import 'ui/settings_page.dart';
import 'ui/trash_page.dart';
import 'ui/users_page.dart';

class JurosApp extends StatefulWidget {
  const JurosApp({super.key, required this.repo, this.auth});

  final Repo repo;
  final AuthApi? auth;

  @override
  State<JurosApp> createState() => _JurosAppState();
}

class _JurosAppState extends State<JurosApp> {
  late final AuthApi auth = widget.auth ?? AuthApi();
  int section = 0;
  late double scale = widget.repo.fontScale;
  SessionUser? user;
  String token = '';
  bool checking = true;

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    final saved = widget.repo.setting('session_token');
    if (saved.isEmpty) {
      if (mounted) setState(() => checking = false);
      return;
    }
    try {
      final me = await auth.me(saved);
      if (!mounted) return;
      setState(() {
        user = me;
        token = saved;
        checking = false;
      });
    } catch (_) {
      widget.repo.removeSetting('session_token');
      if (mounted) setState(() => checking = false);
    }
  }

  void reloadScale() => setState(() => scale = widget.repo.fontScale);

  void enter(SessionUser next, String nextToken) {
    widget.repo.setSetting('session_token', nextToken);
    setState(() {
      user = next;
      token = nextToken;
      section = 0;
    });
  }

  Future<void> leave() async {
    await auth.logout(token);
    widget.repo.removeSetting('session_token');
    if (!mounted) return;
    setState(() {
      user = null;
      token = '';
      section = 0;
    });
  }

  Future<void> changePassword() async {
    final current = user;
    if (current == null) return;
    final next = await askPassword(context, 'Nova senha');
    if (next == null || !mounted) return;
    try {
      await auth.setPassword(token, current.id, next);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha atualizada.')));
    } on AuthException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  List<(IconData, String, int)> destinationsFor(SessionUser current) {
    return [
      (Icons.space_dashboard_outlined, 'Dashboard', 0),
      (Icons.notifications_outlined, 'Cobranças', 1),
      (Icons.people_outline, 'Clientes', 2),
      (Icons.receipt_long_outlined, 'Empréstimos', 3),
      (Icons.account_balance_wallet_outlined, 'Caixa', 4),
      (Icons.bar_chart_outlined, 'Relatórios', 5),
      (Icons.delete_outline, 'Lixeira', 6),
      if (current.isAdmin) ...[
        (Icons.manage_accounts_outlined, 'Usuários', 8),
        (Icons.settings_outlined, 'Configurações', 7),
      ],
    ];
  }

  Widget page(SessionUser current) {
    final allowed = destinationsFor(current).any((item) => item.$3 == section);
    final currentSection = allowed ? section : 0;
    return switch (currentSection) {
      0 => DashboardPage(repo: widget.repo),
      1 => CollectionsPage(repo: widget.repo),
      2 => ClientsPage(repo: widget.repo),
      3 => LoansPage(repo: widget.repo),
      4 => CashPage(repo: widget.repo),
      5 => ReportsPage(repo: widget.repo),
      6 => TrashPage(repo: widget.repo),
      8 => UsersPage(auth: auth, token: token),
      _ => SettingsPage(repo: widget.repo, onChanged: reloadScale),
    };
  }

  @override
  Widget build(BuildContext context) {
    final current = user;
    return MaterialApp(
      title: 'Juros',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: checking
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : current == null
              ? LoginPage(auth: auth, onSuccess: enter)
              : _Shell(
                  user: current,
                  section: destinationsFor(current).any((item) => item.$3 == section) ? section : 0,
                  destinations: destinationsFor(current),
                  onSelected: (id) => setState(() => section = id),
                  onLogout: leave,
                  onPassword: changePassword,
                  child: page(current),
                ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.user,
    required this.section,
    required this.destinations,
    required this.onSelected,
    required this.onLogout,
    required this.onPassword,
    required this.child,
  });

  final SessionUser user;
  final int section;
  final List<(IconData, String, int)> destinations;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final VoidCallback onPassword;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (!wide) {
            return Column(
              children: [
                Expanded(child: SafeArea(bottom: false, child: child)),
                _SectionBar(
                  selected: section,
                  destinations: destinations,
                  accountLabel: '${user.name} · ${user.roleLabel}',
                  onSelected: onSelected,
                  onLogout: onLogout,
                  onPassword: onPassword,
                ),
              ],
            );
          }
          final extended = constraints.maxWidth >= 1180;
          final navIndex = destinations.indexWhere((item) => item.$3 == section);
          return Row(
            children: [
              NavigationRail(
                backgroundColor: AppColors.sidebar,
                extended: extended,
                selectedIndex: navIndex < 0 ? 0 : navIndex,
                onDestinationSelected: (index) => onSelected(destinations[index].$3),
                labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      extended ? 'Juros' : 'J',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.green),
                    ),
                  ),
                ),
                trailing: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  child: extended
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(user.roleLabel, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                            TextButton(onPressed: onPassword, child: const Text('Trocar senha')),
                            TextButton(onPressed: onLogout, child: const Text('Sair')),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(tooltip: 'Trocar senha', onPressed: onPassword, icon: const Icon(Icons.key_outlined)),
                            IconButton(tooltip: 'Sair', onPressed: onLogout, icon: const Icon(Icons.logout)),
                          ],
                        ),
                ),
                destinations: [
                  for (final item in destinations)
                    NavigationRailDestination(icon: Icon(item.$1), label: Text(item.$2)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  const _SectionBar({
    required this.selected,
    required this.destinations,
    required this.accountLabel,
    required this.onSelected,
    required this.onLogout,
    required this.onPassword,
  });

  final int selected;
  final List<(IconData, String, int)> destinations;
  final String accountLabel;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final VoidCallback onPassword;

  static const primary = [0, 1, 2, 3];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sidebar,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final index in primary)
                if (index < destinations.length) Expanded(child: _slot(index)),
              Expanded(child: _more(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(int index) {
    final item = destinations[index];
    return _NavSlot(
      icon: item.$1,
      label: item.$2,
      selected: selected == item.$3,
      onTap: () => onSelected(item.$3),
    );
  }

  Widget _more(BuildContext context) {
    final selectedIndex = destinations.indexWhere((item) => item.$3 == selected);
    final extra = selectedIndex >= primary.length;
    final current = extra ? destinations[selectedIndex] : null;
    return _NavSlot(
      icon: current?.$1 ?? Icons.more_horiz,
      label: current?.$2 ?? 'Mais',
      selected: extra,
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.card,
          builder: (sheetContext) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(accountLabel),
                    subtitle: const Text('Conta'),
                  ),
                  for (var index = primary.length; index < destinations.length; index++)
                    ListTile(
                      leading: Icon(
                        destinations[index].$1,
                        color: selected == destinations[index].$3 ? AppColors.green : AppColors.muted,
                      ),
                      title: Text(destinations[index].$2),
                      selected: selected == destinations[index].$3,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onSelected(destinations[index].$3);
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Trocar senha'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onPassword();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sair'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onLogout();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
