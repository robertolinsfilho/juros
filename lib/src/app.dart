import 'package:flutter/material.dart';

import 'auth/auth_api.dart';
import 'data/repository.dart';
import 'theme.dart';
import 'ui/cash_page.dart';
import 'ui/clients_page.dart';
import 'ui/collections_page.dart';
import 'ui/dashboard_page.dart';
import 'ui/loans_page.dart';
import 'ui/profile_page.dart';
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

  int visibleSection(SessionUser current) {
    if (section == 9) return 9;
    final allowed = destinationsFor(current).any((item) => item.$3 == section);
    return allowed ? section : 0;
  }

  Widget page(SessionUser current) {
    final currentSection = visibleSection(current);
    if (currentSection == 9) {
      return ProfilePage(
        auth: auth,
        token: token,
        user: current,
        onUpdated: (next) => setState(() => user = next),
      );
    }
    return switch (currentSection) {
      0 => DashboardPage(repo: widget.repo),
      1 => CollectionsPage(repo: widget.repo),
      2 => ClientsPage(repo: widget.repo),
      3 => LoansPage(repo: widget.repo),
      4 => CashPage(repo: widget.repo),
      5 => ReportsPage(repo: widget.repo),
      6 => TrashPage(repo: widget.repo),
      8 => UsersPage(auth: auth, token: token, selfId: current.id),
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
                  section: visibleSection(current),
                  destinations: destinationsFor(current),
                  onSelected: (id) => setState(() => section = id),
                  onProfile: () => setState(() => section = 9),
                  onLogout: leave,
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
    required this.onProfile,
    required this.onLogout,
    required this.child,
  });

  final SessionUser user;
  final int section;
  final List<(IconData, String, int)> destinations;
  final ValueChanged<int> onSelected;
  final VoidCallback onProfile;
  final VoidCallback onLogout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final page = Column(
            children: [
              _AccountBar(user: user, profileOpen: section == 9, onProfile: onProfile, onLogout: onLogout),
              Expanded(child: child),
            ],
          );
          if (!wide) {
            return Column(
              children: [
                Expanded(child: SafeArea(bottom: false, child: page)),
                _SectionBar(
                  selected: section,
                  destinations: destinations,
                  onSelected: onSelected,
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
                selectedIndex: navIndex < 0 ? null : navIndex,
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
                destinations: [
                  for (final item in destinations)
                    NavigationRailDestination(icon: Icon(item.$1), label: Text(item.$2)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: page),
            ],
          );
        },
      ),
    );
  }
}

class _AccountBar extends StatelessWidget {
  const _AccountBar({
    required this.user,
    required this.profileOpen,
    required this.onProfile,
    required this.onLogout,
  });

  final SessionUser user;
  final bool profileOpen;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sidebar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = Row(
              children: [
                const Icon(Icons.account_circle_outlined, color: AppColors.green, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(user.roleLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: onProfile,
                  child: Text(
                    'Perfil',
                    style: TextStyle(fontWeight: profileOpen ? FontWeight.w700 : null),
                  ),
                ),
                TextButton(onPressed: onLogout, child: const Text('Sair')),
              ],
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  actions,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  const _SectionBar({
    required this.selected,
    required this.destinations,
    required this.onSelected,
  });

  final int selected;
  final List<(IconData, String, int)> destinations;
  final ValueChanged<int> onSelected;

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
              child: ListView(
                shrinkWrap: true,
                children: [
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
