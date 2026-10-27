import 'package:flutter/material.dart';

import 'data/repository.dart';
import 'theme.dart';
import 'ui/cash_page.dart';
import 'ui/clients_page.dart';
import 'ui/collections_page.dart';
import 'ui/dashboard_page.dart';
import 'ui/loans_page.dart';
import 'ui/reports_page.dart';
import 'ui/settings_page.dart';
import 'ui/trash_page.dart';

class JurosApp extends StatefulWidget {
  const JurosApp({super.key, required this.repo});

  final Repo repo;

  @override
  State<JurosApp> createState() => _JurosAppState();
}

class _JurosAppState extends State<JurosApp> {
  int section = 0;
  late double scale = widget.repo.fontScale;

  static const destinations = [
    (Icons.space_dashboard_outlined, 'Dashboard'),
    (Icons.notifications_outlined, 'Cobranças'),
    (Icons.people_outline, 'Clientes'),
    (Icons.receipt_long_outlined, 'Empréstimos'),
    (Icons.account_balance_wallet_outlined, 'Caixa'),
    (Icons.bar_chart_outlined, 'Relatórios'),
    (Icons.delete_outline, 'Lixeira'),
    (Icons.settings_outlined, 'Configurações'),
  ];

  void reloadScale() => setState(() => scale = widget.repo.fontScale);

  Widget page() {
    return switch (section) {
      0 => DashboardPage(repo: widget.repo),
      1 => CollectionsPage(repo: widget.repo),
      2 => ClientsPage(repo: widget.repo),
      3 => LoansPage(repo: widget.repo),
      4 => CashPage(repo: widget.repo),
      5 => ReportsPage(repo: widget.repo),
      6 => TrashPage(repo: widget.repo),
      _ => SettingsPage(repo: widget.repo, onChanged: reloadScale),
    };
  }

  @override
  Widget build(BuildContext context) {
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
      home: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final content = page();
            if (!wide) {
              return Column(
                children: [
                  Expanded(child: SafeArea(bottom: false, child: content)),
                  _SectionBar(
                    selected: section,
                    destinations: destinations,
                    onSelected: (index) => setState(() => section = index),
                  ),
                ],
              );
            }
            return Row(
              children: [
                NavigationRail(
                  backgroundColor: AppColors.sidebar,
                  extended: constraints.maxWidth >= 1180,
                  selectedIndex: section,
                  onDestinationSelected: (index) => setState(() => section = index),
                  labelType: constraints.maxWidth >= 1180 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Juros', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.green)),
                    ),
                  ),
                  destinations: [
                    for (final item in destinations)
                      NavigationRailDestination(icon: Icon(item.$1), label: Text(item.$2)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
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
  final List<(IconData, String)> destinations;
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
              for (final index in primary) Expanded(child: _slot(index)),
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
      selected: selected == index,
      onTap: () => onSelected(index),
    );
  }

  Widget _more(BuildContext context) {
    final extra = selected >= primary.length;
    final label = extra ? destinations[selected].$2 : 'Mais';
    return _NavSlot(
      icon: extra ? destinations[selected].$1 : Icons.more_horiz,
      label: label,
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
                  for (var index = primary.length; index < destinations.length; index++)
                    ListTile(
                      leading: Icon(destinations[index].$1, color: selected == index ? AppColors.green : AppColors.muted),
                      title: Text(destinations[index].$2),
                      selected: selected == index,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onSelected(index);
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
