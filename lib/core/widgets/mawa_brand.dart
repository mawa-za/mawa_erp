import 'package:flutter/material.dart';

class MawaBrand extends StatelessWidget {
  const MawaBrand({super.key, this.height = 42, this.grey = false, this.semanticLabel = 'MAWA'});

  final double height;
  final bool grey;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      grey ? 'assets/branding/mawa_logo_grey.png' : 'assets/branding/mawa_logo_red.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: semanticLabel,
      errorBuilder: (_, __, ___) => Text('MAWA', style: TextStyle(fontSize: height * .55, fontWeight: FontWeight.w900)),
    );
  }
}
