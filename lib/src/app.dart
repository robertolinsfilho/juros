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
                  Expanded(child: content),
                  NavigationBar(
                    selectedIndex: section,
                    onDestinationSelected: (index) => setState(() => section = index),
                    destinations: [
                      for (final item in destinations)
                        NavigationDestination(icon: Icon(item.$1), label: item.$2),
                    ],
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
