import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(steps.length, (index) {
            final isCompleted = index < currentStep;
            final isActive = index == currentStep;
            final theme = Theme.of(context);

            return Row(
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isCompleted
                          ? Colors.green
                          : (isActive ? theme.primaryColor : Colors.grey.shade300),
                      child: isCompleted
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive ? Colors.white : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? theme.primaryColor : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 30,
                    height: 2,
                    margin: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
                    color: isCompleted ? Colors.green : Colors.grey.shade300,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
