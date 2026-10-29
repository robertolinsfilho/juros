import 'package:flutter/material.dart';

import '../theme.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: narrow ? Theme.of(context).textTheme.headlineSmall : Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: Space.tight),
        Text(subtitle, style: const TextStyle(color: AppColors.muted)),
      ],
    );
    final actionBlock = Wrap(spacing: Space.compact, runSpacing: Space.compact, children: actions);
    if (narrow || actions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          if (actions.isNotEmpty) ...[const SizedBox(height: Space.base), actionBlock],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: Space.base),
        actionBlock,
      ],
    );
  }
}

EdgeInsets pagePadding(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  return EdgeInsets.all(wide ? Space.page : Space.base);
}

double dialogWidth(BuildContext context, double maxWidth) {
  final available = MediaQuery.sizeOf(context).width - 32;
  return available < maxWidth ? available : maxWidth;
}

class FieldPair extends StatelessWidget {
  const FieldPair({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(
            children: [
              left,
              const SizedBox(height: Space.base),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: Space.base),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(height: Space.tight),
          Text(subtitle!, style: const TextStyle(color: AppColors.muted)),
        ],
      ],
    );
    final buttons = Wrap(
      spacing: Space.compact,
      runSpacing: Space.compact,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.base, vertical: Space.base),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text,
                  if (actions.isNotEmpty) ...[const SizedBox(height: Space.compact), buttons],
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: text),
                if (actions.isNotEmpty) ...[const SizedBox(width: Space.base), buttons],
              ],
            );
          },
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(Space.base)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    this.accent = AppColors.text,
  });

  final String label;
  final String value;
  final String caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.4)),
          const SizedBox(height: Space.compact),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: accent)),
          ),
          const SizedBox(height: Space.tight),
          Text(caption, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.section),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 36),
          const SizedBox(height: Space.compact),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: Space.tight),
          Text(body, style: const TextStyle(color: AppColors.muted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Atrasado' || 'Perdido' => AppColors.red,
      'Quitado' || 'Em dia' || 'Pago' => AppColors.green,
      'Vence hoje' => AppColors.amber,
      _ => AppColors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.compact, vertical: Space.tight),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

Future<bool> confirmAction(BuildContext context, String title, String body) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
      ],
    ),
  );
  return result ?? false;
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Widget metricGrid(List<Widget> cards) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 480 ? 2 : 1;
      const gap = Space.base;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final card in cards) SizedBox(width: width, child: card)],
      );
    },
  );
}

Widget sideBySide(Widget left, Widget right) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 720) {
        return Column(
          children: [
            left,
            const SizedBox(height: Space.base),
            right,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: Space.base),
          Expanded(child: right),
        ],
      );
    },
  );
}
