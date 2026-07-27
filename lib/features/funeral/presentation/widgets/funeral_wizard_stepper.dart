import 'package:flutter/material.dart';

import '../../../../core/theme/mawa_design.dart';

class FuneralWizardStepper extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const FuneralWizardStepper({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: MawaDesign.surface,
        border: Border(bottom: BorderSide(color: MawaDesign.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: List.generate(steps.length, (index) {
            final completed = index < currentStep;
            final active = index == currentStep;
            final connectorCompleted = index < currentStep;
            final circleColor = completed
                ? MawaDesign.success
                : active
                    ? MawaDesign.red
                    : const Color(0xFFE5E7EB);
            final labelColor = active
                ? MawaDesign.red
                : completed
                    ? MawaDesign.navy
                    : MawaDesign.textMuted;

            return Row(
              children: [
                SizedBox(
                  width: 74,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: circleColor,
                          shape: BoxShape.circle,
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: MawaDesign.red.withValues(alpha: 0.18),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: completed
                            ? const Icon(
                                Icons.check_rounded,
                                size: 17,
                                color: Colors.white,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: active
                                      ? Colors.white
                                      : MawaDesign.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[index],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 10.5,
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 34,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 21),
                    decoration: BoxDecoration(
                      color: connectorCompleted
                          ? MawaDesign.success
                          : MawaDesign.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
