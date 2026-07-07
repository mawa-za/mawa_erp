import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';

class FuneralMoneyText extends StatelessWidget {
  final int cents;
  final TextStyle? style;

  const FuneralMoneyText({super.key, required this.cents, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      Formatters.formatCentsAsRand(cents),
      style: style,
    );
  }
}
