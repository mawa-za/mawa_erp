import 'package:flutter/material.dart';
import 'case_detail_screen.dart';

class CaseDetailShellScreen extends StatelessWidget {
  final String caseId;
  final String? initialTab;

  const CaseDetailShellScreen({
    super.key,
    required this.caseId,
    this.initialTab,
  });

  @override
  Widget build(BuildContext context) {
    return CaseDetailScreen(
      caseId: caseId,
      initialTab: initialTab,
    );
  }
}
