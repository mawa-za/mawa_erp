import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/legal_case.dart';

class CaseOverviewTab extends StatelessWidget {
  final LegalCase legalCase;
  const CaseOverviewTab({super.key, required this.legalCase});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            context,
            'General Information',
            [
              _buildInfoRow('Title', legalCase.title),
              _buildInfoRow('Case No', legalCase.caseNo),
              _buildInfoRow('Case Type', legalCase.caseType),
              _buildInfoRow('Category', legalCase.caseCategory ?? 'N/A'),
              _buildInfoRow('Priority', legalCase.priority),
              _buildInfoRow('Opened Date', legalCase.openedDate != null ? DateFormat('dd MMM yyyy').format(legalCase.openedDate!) : 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            'Client & Assignment',
            [
              _buildInfoRow('Client', legalCase.clientPartnerName ?? 'N/A'),
              _buildInfoRow('Assigned To', legalCase.assignedToName ?? 'Unassigned'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            'Court Details',
            [
              _buildInfoRow('Court Name', legalCase.courtName ?? 'N/A'),
              _buildInfoRow('Court Case No', legalCase.courtCaseNo ?? 'N/A'),
              _buildInfoRow('Forum Type', legalCase.forumType ?? 'N/A'),
              _buildInfoRow('Next Appearance', legalCase.nextAppearanceDate != null ? DateFormat('dd MMM yyyy').format(legalCase.nextAppearanceDate!) : 'None set'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            'Description',
            [
              Text(
                legalCase.description ?? 'No description provided',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            'Billing Setup',
            [
              _buildInfoRow('Billing Type', legalCase.billingType),
              _buildInfoRow('Hourly Rate', 'R ${(legalCase.hourlyRateCents / 100).toStringAsFixed(2)}'),
              _buildInfoRow('Fixed Fee', 'R ${(legalCase.fixedFeeCents / 100).toStringAsFixed(2)}'),
              _buildInfoRow('Billable', legalCase.billable ? 'Yes' : 'No'),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
