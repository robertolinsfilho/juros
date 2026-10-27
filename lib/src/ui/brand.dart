import 'package:flutter/material.dart';

import '../theme.dart';

const brandName = 'Acertaí';
const brandTagline = 'Suas finanças no lugar certo';

/// Só o símbolo (o "A" com a seta).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/mark.png',
      height: size,
      semanticLabel: brandName,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Logo completa: símbolo, nome e frase.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.width = 240});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/logo.png',
      width: width,
      semanticLabel: '$brandName — $brandTagline',
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Nome da marca, com o pingo do "i" em verde-limão.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: -0.4,
        ),
        children: const [
          TextSpan(text: 'acerta'),
          TextSpan(text: 'í', style: TextStyle(color: AppColors.lime)),
        ],
      ),
    );
  }
}

/// Símbolo ao lado do nome, para barras e rodapés.
class BrandName extends StatelessWidget {
  const BrandName({super.key, this.size = 30, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: size),
        if (showName) ...[
          SizedBox(width: size * 0.3),
          BrandWordmark(size: size * 0.62),
        ],
      ],
    );
  }
}
