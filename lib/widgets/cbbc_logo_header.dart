import 'package:flutter/material.dart';

import '../theme/cbbc_theme.dart';

const String kCbbcLogoAsset = 'assets/images/cbbc-logo.png';

/// Cabeçalho institucional usado na home.
class CbbcBrandHeader extends StatelessWidget {
  const CbbcBrandHeader({
    super.key,
    this.title = 'Controle de Classificação CBBC',
    this.subtitle,
    this.maxLogoHeight = 140,
  });

  final String title;
  final String? subtitle;
  final double maxLogoHeight;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext _, BoxConstraints c) {
            final double availableHeight =
                c.maxHeight.isFinite ? c.maxHeight : maxLogoHeight;
            final double height =
                availableHeight < maxLogoHeight ? availableHeight : maxLogoHeight;
            return SizedBox(
              key: const Key('cbbc-brand-logo'),
              height: height,
              child: Image.asset(
                kCbbcLogoAsset,
                fit: BoxFit.contain,
                semanticLabel: 'Logo CBBC',
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: CbbcColors.blueDeep,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: CbbcColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Título empilhado (logo branco em cima, texto da tela embaixo) usado nas
/// `AppBar`s azuis das telas internas. O logo é tintado de branco via
/// `ColorFilter` pra ficar legível sobre o fundo azul cobalto.
class CbbcAppBarTitle extends StatelessWidget {
  const CbbcAppBarTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          key: const Key('cbbc-appbar-logo'),
          height: 38,
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
            child: Image.asset(
              kCbbcLogoAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Logo CBBC',
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
