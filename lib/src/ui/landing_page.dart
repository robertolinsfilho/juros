import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'brand.dart';

const _maxWidth = 1040.0;

/// Página inicial mostrada antes do login.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key, required this.onEnter});

  final VoidCallback onEnter;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final scroll = ScrollController();
  final howKey = GlobalKey();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void showHow() {
    final context = howKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Column(
            children: [
              _Header(onEnter: widget.onEnter),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    children: [
                      _Hero(wide: wide, onEnter: widget.onEnter, onHow: showHow),
                      const _Strip(),
                      _Band(child: _Highlight(wide: wide)),
                      _Band(child: _Compare(wide: wide)),
                      KeyedSubtree(key: howKey, child: _Band(child: _Features(wide: wide))),
                      _Band(child: _Steps(wide: wide)),
                      const _Band(child: _Faq()),
                      _Band(child: _Cta(onEnter: widget.onEnter)),
                      const _Footer(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Row(
            children: [
              const _Logo(),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width >= 480) ...[
                TextButton(onPressed: onEnter, child: const Text('Entrar')),
                const SizedBox(width: 8),
              ],
              FilledButton(onPressed: onEnter, child: Text(MediaQuery.sizeOf(context).width >= 480 ? 'Acessar' : 'Entrar')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const BrandName(size: 30);
  }
}

/// Faixa centralizada com a largura máxima do conteúdo.
class _Band extends StatelessWidget {
  const _Band({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 56), child: child),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {this.center = true});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.center = true});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.color, this.border, this.padding = const EdgeInsets.all(18), this.radius = 16});

  final Widget child;
  final Color? color;
  final Color? border;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? AppColors.line),
      ),
      child: child,
    );
  }
}

// ───────────────────────────── Hero ─────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.wide, required this.onEnter, required this.onHow});

  final bool wide;
  final VoidCallback onEnter;
  final VoidCallback onHow;

  Widget copy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 14, color: AppColors.green),
              SizedBox(width: 6),
              Flexible(
                child: Text('Acesso exclusivo · dados protegidos', style: TextStyle(color: AppColors.green, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: wide ? 56 : 40, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -1.2),
            children: const [
              TextSpan(text: 'Chega de caderno.\n'),
              TextSpan(text: 'O Acertaí lembra por você.', style: TextStyle(color: AppColors.lime)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Veja de relance quem vence hoje, quem atrasou e quem já pagou. '
          'Cadastre clientes, monte o empréstimo e cobre pelo WhatsApp em poucos toques.',
          style: TextStyle(color: AppColors.muted, fontSize: 17, height: 1.5),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: onEnter,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text('Começar 3 dias grátis', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onHow,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18)),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Ver como funciona'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Parcelas calculadas sozinhas · 3 dias grátis · Funciona no celular e no computador',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.9, -0.6),
                radius: 1.1,
                colors: [AppColors.green.withValues(alpha: 0.14), Colors.transparent],
              ),
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, wide ? 72 : 40, 20, wide ? 80 : 48),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 11, child: copy()),
                        const SizedBox(width: 48),
                        const Expanded(flex: 10, child: _DashboardPreview()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [copy(), const SizedBox(height: 40), const _DashboardPreview()],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardPreview extends StatelessWidget {
  const _DashboardPreview();

  Widget row(String name, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          _Pill(status, color),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 22),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
              boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.10), blurRadius: 50, spreadRadius: 2)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recebimentos', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 2),
                const Row(
                  children: [
                    Expanded(child: Text('Prévia do painel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    _Pill('EXEMPLO', AppColors.green),
                  ],
                ),
                const SizedBox(height: 14),
                const SizedBox(height: 120, width: double.infinity, child: CustomPaint(painter: _ChartPainter())),
                const SizedBox(height: 14),
                row('Maria S.', 'Vence hoje', AppColors.amber),
                row('João P.', 'Pago', AppColors.green),
                row('Carlos M.', 'Vence amanhã', AppColors.muted),
              ],
            ),
          ),
          Positioned(
            top: -16,
            right: -6,
            child: _Box(
              color: AppColors.card,
              border: AppColors.amber.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              radius: 12,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 18, color: AppColors.amber),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('3 vencem hoje', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      Text('R\$ 1.170 no total', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -16,
            left: -6,
            child: _Box(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              radius: 12,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: AppColors.green),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pagamento confirmado', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      Text('enviado pelo WhatsApp', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const values = [0.15, 0.22, 0.18, 0.35, 0.3, 0.5, 0.42, 0.62, 0.55, 0.8, 0.95];
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(size.width * i / (values.length - 1), size.height * (1 - values[i] * 0.9) - 4),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final middle = (previous.dx + current.dx) / 2;
      line.cubicTo(middle, previous.dy, middle, current.dy, current.dx, current.dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.green.withValues(alpha: 0.35), AppColors.green.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ───────────────────────────── Faixa de recursos ─────────────────────────────

class _Strip extends StatelessWidget {
  const _Strip();

  static const items = [
    'Parcelado',
    'Juros + capital',
    'Diário',
    'Semanal',
    'Quinzenal',
    'Mensal',
    'Cobrança no WhatsApp',
    'Cálculo automático',
    'Funciona no celular',
    'Sem papelada',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.line)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 28,
        runSpacing: 10,
        children: [
          for (final item in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 5, color: AppColors.green),
                const SizedBox(width: 8),
                Text(item, style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Destaque ─────────────────────────────

class _Highlight extends StatelessWidget {
  const _Highlight({required this.wide});

  final bool wide;

  Widget bullet(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(text, style: const TextStyle(fontSize: 15, height: 1.3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget copy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('Para não esquecer ninguém', center: false),
        const SizedBox(height: 10),
        const _Title('Abriu o sistema, já sabe quem está devendo', center: false),
        const SizedBox(height: 16),
        const Text(
          'O descuido mais caro de quem empresta é deixar uma parcela passar. O Acertaí mostra, todo dia, '
          'o que venceu e o que vence logo, sem depender da sua memória.',
          style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 22),
        bullet(Icons.notifications_none, 'Vencidos e a vencer aparecem assim que você entra'),
        bullet(Icons.chat_bubble_outline, 'Cobrança no WhatsApp com a mensagem já pronta'),
        bullet(Icons.check_circle_outline, 'Parcela recebida sai da lista de pendências na hora'),
      ],
    );
  }

  Widget notice(String name, String status, String amount, Color color, IconData icon, {bool tinted = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tinted ? color.withValues(alpha: 0.08) : AppColors.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tinted ? color.withValues(alpha: 0.35) : AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: 0.6), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(status, style: TextStyle(color: color, fontSize: 11)),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }

  Widget card() {
    return _Box(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.circle, size: 8, color: AppColors.green),
              SizedBox(width: 8),
              Expanded(child: Text('Cobranças', style: TextStyle(fontWeight: FontWeight.w700))),
              _Pill('EXEMPLO ILUSTRATIVO', AppColors.green),
            ],
          ),
          const SizedBox(height: 14),
          notice('Marcos A.', 'Pago', 'R\$ 480', AppColors.green, Icons.check_circle_outline),
          notice('Paula R.', 'Vence amanhã', 'R\$ 600', AppColors.muted, Icons.schedule, tinted: false),
          notice('Rafael T.', 'Atrasado há 1 dia', 'R\$ 900', AppColors.red, Icons.warning_amber_rounded),
          notice('Sônia L.', 'Vence hoje', 'R\$ 220', AppColors.amber, Icons.notifications_none),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [copy(), const SizedBox(height: 32), card()]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: copy()),
        const SizedBox(width: 56),
        Expanded(child: card()),
      ],
    );
  }
}

// ───────────────────────────── Comparação ─────────────────────────────

class _Compare extends StatelessWidget {
  const _Compare({required this.wide});

  final bool wide;

  Widget column(String title, List<String> items, {required bool good}) {
    final color = good ? AppColors.green : AppColors.red;
    return _Box(
      color: good ? AppColors.green.withValues(alpha: 0.05) : AppColors.card,
      border: good ? AppColors.green.withValues(alpha: 0.35) : AppColors.line,
      padding: const EdgeInsets.all(22),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: good ? AppColors.green : AppColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(good ? Icons.check : Icons.close, size: 12, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(fontSize: 14, height: 1.3, color: good ? AppColors.text : AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final old = column('Jeito antigo', const [
      'Anotações que só você consegue ler',
      'Parcela vencida que ninguém percebe',
      'Cobrança de cabeça, cliente por cliente',
      'Juros calculados na mão, com risco de erro',
    ], good: false);
    final now = column('Com o Acertaí', const [
      'Clientes e contratos num lugar só',
      'Vencimentos de hoje e da semana sempre à vista',
      'Cobrança no WhatsApp com poucos toques',
      'Juros e parcelas calculados automaticamente',
    ], good: true);
    return Column(
      children: [
        const _Eyebrow('A diferença'),
        const SizedBox(height: 10),
        const _Title('Do caderno para o controle de verdade'),
        const SizedBox(height: 32),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [Expanded(child: old), const SizedBox(width: 16), Expanded(child: now)],
                  ),
                )
              : Column(children: [old, const SizedBox(height: 16), now]),
        ),
      ],
    );
  }
}

// ───────────────────────────── Funcionalidades ─────────────────────────────

class _Features extends StatelessWidget {
  const _Features({required this.wide});

  final bool wide;

  Widget iconBox(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, size: 20, color: AppColors.green),
    );
  }

  Widget small(IconData icon, String title, String text) {
    return _Box(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          iconBox(icon),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget counter(String label, String value, Color color, {bool tinted = true}) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tinted ? color.withValues(alpha: 0.08) : AppColors.bg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tinted ? color.withValues(alpha: 0.3) : AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 12))),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget big() {
    return _Box(
      color: AppColors.green.withValues(alpha: 0.05),
      border: AppColors.green.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(22),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          iconBox(Icons.notifications_none),
          const SizedBox(height: 18),
          const Text('Vencimentos em dia', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 6),
          const Text(
            'O que vence hoje e nesta semana, reunido numa tela só.',
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 18),
          counter('Vencem hoje', '3', AppColors.amber),
          counter('Vencem amanhã', '2', AppColors.muted, tinted: false),
          counter('Recebidos na semana', '8', AppColors.green),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = small(Icons.payments_outlined, 'Parcelado ou só juros', 'Parcelas fixas, amortização ou juros com o capital devolvido no final.');
    final b = small(Icons.people_outline, 'Ficha do cliente', 'Contratos, parcelas e pagamentos de cada pessoa no mesmo lugar.');
    final c = small(Icons.event_repeat, 'Qualquer frequência', 'Diária, semanal, quinzenal, mensal ou a cada tantos dias.');
    final d = small(Icons.chat_bubble_outline, 'WhatsApp com texto pronto', 'Mensagens de cobrança e de confirmação que você personaliza.');
    final e = small(Icons.devices_outlined, 'Celular ou computador', 'Abre direto no navegador, sem instalar nada.');
    return Column(
      children: [
        const _Eyebrow('Funcionalidades'),
        const SizedBox(height: 10),
        const _Title('Tudo que o dia a dia pede, sem complicação'),
        const SizedBox(height: 32),
        if (wide) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: big()),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [Expanded(child: a), const SizedBox(height: 16), Expanded(child: b)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: c),
                const SizedBox(width: 16),
                Expanded(child: d),
                const SizedBox(width: 16),
                Expanded(child: e),
              ],
            ),
          ),
        ] else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in [big(), a, b, c, d, e]) Padding(padding: const EdgeInsets.only(bottom: 14), child: item),
            ],
          ),
      ],
    );
  }
}

// ───────────────────────────── Passos ─────────────────────────────

class _Steps extends StatelessWidget {
  const _Steps({required this.wide});

  final bool wide;

  Widget step(int index, String title, String text) {
    final opacity = 1.0 - index * 0.22;
    return _Box(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.green.withValues(alpha: opacity),
            ),
            child: Text(
              '0${index + 1}',
              style: const TextStyle(color: AppColors.greenInk, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget trust(IconData icon, String title, String text) {
    return _Box(
      color: AppColors.card.withValues(alpha: 0.6),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: AppColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      trust(Icons.shield_outlined, 'Conexão segura', 'Acesso por HTTPS e login individual.'),
      trust(Icons.bolt_outlined, 'Rápido de usar', 'O primeiro empréstimo sai em poucos minutos.'),
      trust(Icons.smartphone, 'Sempre à mão', 'Adicione à tela inicial do celular e use como aplicativo.'),
    ];
    return Column(
      children: [
        const _Eyebrow('Como funciona'),
        const SizedBox(height: 10),
        const _Title('Três passos, do cadastro à cobrança'),
        const SizedBox(height: 32),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              step(0, 'Cadastre o cliente', 'Nome e WhatsApp bastam para começar.'),
              const SizedBox(height: 12),
              step(1, 'Monte o empréstimo', 'Informe valor, juros, parcelas e frequência.'),
              const SizedBox(height: 12),
              step(2, 'Acompanhe os recebimentos', 'Veja vencimentos, pagamentos e saldo sempre atualizados.'),
            ],
          ),
        ),
        const SizedBox(height: 40),
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: items[i]),
                ],
              ],
            ),
          )
        else
          Column(
            children: [for (final item in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: item)],
          ),
      ],
    );
  }
}

// ───────────────────────────── Perguntas ─────────────────────────────

class _Faq extends StatelessWidget {
  const _Faq();

  static const questions = [
    (
      'Quem pode usar?',
      'O acesso é por login individual. O administrador cria os usuários na tela Usuários.',
    ),
    (
      'Quais tipos de empréstimo posso criar?',
      'Parcelado com valor fixo ou amortizado, e juros com o capital devolvido no final. '
          'A frequência pode ser diária, semanal, quinzenal, mensal ou personalizada.',
    ),
    (
      'Como funciona a cobrança?',
      'Em Cobranças você vê o que venceu e o que vence. Com um toque abre o WhatsApp com a mensagem pronta, '
          'que muda conforme a situação da parcela.',
    ),
    (
      'Funciona no celular?',
      'Sim. Abra o endereço no navegador do celular e, se quiser, adicione à tela inicial.',
    ),
    (
      'Onde ficam os meus dados?',
      'Clientes e empréstimos ficam guardados no navegador do aparelho em que você usa. '
          'O login e as suas configurações de mensagens ficam no servidor, protegidos por HTTPS.',
    ),
    (
      'E se eu apagar um empréstimo sem querer?',
      'Os empréstimos excluídos vão para a Lixeira e podem ser restaurados por até 30 dias.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Eyebrow('Dúvidas'),
        const SizedBox(height: 10),
        const _Title('Perguntas frequentes'),
        const SizedBox(height: 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              for (final item in questions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: AppColors.card,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                        expandedAlignment: Alignment.centerLeft,
                        title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        children: [
                          Text(item.$2, style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── Chamada final e rodapé ─────────────────────────────

class _Cta extends StatelessWidget {
  const _Cta({required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.green.withValues(alpha: 0.16), AppColors.green.withValues(alpha: 0.03)],
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Pronto para organizar seus recebimentos?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 10),
          const Text(
            'Comece agora e use 3 dias grátis. Depois, a partir de R\$ 49,99 por mês.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onEnter,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18)),
            child: const Text('Começar 3 dias grátis'),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            spacing: 24,
            children: [
              const _Logo(),
              Text(
                '© ${math.max(2026, DateTime.now().year)} Acertaí Finanças. Todos os direitos reservados.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
