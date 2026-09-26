import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../services/legal_practice_service.dart';

enum LegalPracticeMode {
  dashboard,
  intake,
  conflicts,
  diary,
  timeBilling,
  trust,
  trustReconciliation,
  reports,
  administration,
}

class LegalPracticeScreen extends StatefulWidget {
  final String? resource;
  final String title;
  final LegalPracticeMode mode;

  const LegalPracticeScreen({
    super.key,
    this.resource,
    this.title = 'Legal Practice',
    this.mode = LegalPracticeMode.dashboard,
  });

  @override
  State<LegalPracticeScreen> createState() => _LegalPracticeScreenState();
}

class _LegalPracticeScreenState extends State<LegalPracticeScreen> {
  final _service = LegalPracticeService();
  bool _loading = true;
  dynamic _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (widget.mode == LegalPracticeMode.dashboard) {
        _data = await _service.dashboard();
      } else if (widget.resource != null) {
        _data = await _service.list(widget.resource!);
      } else {
        _data = null;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back to Legal Practice',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/feature-groups/legal-practice');
              }
            },
          ),
          title: Text(widget.title),
          actions: [
            if (widget.resource != null || widget.mode == LegalPracticeMode.dashboard)
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      );

  Widget _buildBody() {
    switch (widget.mode) {
      case LegalPracticeMode.dashboard:
        return _dashboard();
      case LegalPracticeMode.intake:
        return _intake();
      case LegalPracticeMode.conflicts:
        return _records('No conflict checks recorded yet.');
      case LegalPracticeMode.diary:
        return _hub([
          _Action('Upcoming events', 'Hearings, consultations and deadlines across matters.', Icons.calendar_month, AppRoutes.caseUpcomingEvents),
          _Action('Overdue tasks', 'Legal tasks requiring attention.', Icons.task_alt, AppRoutes.caseOverdueTasks),
          _Action('Matters', 'Open a matter to manage its events and tasks.', Icons.folder_open, AppRoutes.cases),
        ]);
      case LegalPracticeMode.timeBilling:
        return _hub([
          _Action('Unbilled matters', 'Review WIP before billing.', Icons.request_quote, AppRoutes.caseUnbilled),
          _Action('Matters', 'Capture time and disbursements from the matter.', Icons.schedule, AppRoutes.cases),
          _Action('Invoices', 'Continue approved legal billing in MAWA invoicing.', Icons.receipt_long, AppRoutes.invoices),
        ]);
      case LegalPracticeMode.trust:
        return _hub([
          _Action('Matter trust accounts', 'Receipts, payments, refunds and transfers remain attached to the matter ledger.', Icons.account_balance_wallet, AppRoutes.cases),
          _Action('Trust reconciliation', 'Review bank and client-ledger reconciliation records.', Icons.fact_check, AppRoutes.legalTrustReconciliation),
        ]);
      case LegalPracticeMode.trustReconciliation:
        return _records('No trust reconciliations recorded yet.');
      case LegalPracticeMode.reports:
        return _hub([
          _Action('Matter register', 'Matter status, type, responsible attorney and lifecycle reporting.', Icons.folder_copy, AppRoutes.cases),
          _Action('Unbilled matters', 'WIP and billing readiness.', Icons.analytics, AppRoutes.caseUnbilled),
          _Action('Legal diary', 'Operational deadlines and workload.', Icons.event_note, AppRoutes.legalDiary),
        ]);
      case LegalPracticeMode.administration:
        return _hub([
          _Action('Matter configuration', 'Matter types, stages and legal process configuration.', Icons.tune, AppRoutes.cases),
        ]);
    }
  }

  Widget _dashboard() {
    final d = Map<String, dynamic>.from(_data ?? {});
    final metrics = <String, String>{
      'Open matters': 'openMatters',
      'Open intakes': 'openIntakes',
      'Pending conflicts': 'pendingConflicts',
      'Hearings – next 30 days': 'upcomingHearings',
      'Trust reconciliations open': 'unreconciledTrust',
    };
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: metrics.entries.map((entry) => SizedBox(
            width: 240,
            child: Card(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.key),
                const SizedBox(height: 8),
                Text('${d[entry.value] ?? 0}', style: Theme.of(context).textTheme.headlineMedium),
              ]),
            )),
          )).toList(),
        ),
        const SizedBox(height: 24),
        _hub([
          _Action('Client Intake', 'Prospects, consultations, conflict checks and onboarding.', Icons.person_add, AppRoutes.legalIntake),
          _Action('Matters', 'The central workspace for all legal instructions and matter types.', Icons.folder_open, AppRoutes.cases),
          _Action('Legal Diary', 'Events, deadlines and tasks across matters.', Icons.calendar_month, AppRoutes.legalDiary),
          _Action('Time & Billing', 'Time, disbursements, WIP and billing.', Icons.request_quote, AppRoutes.legalTimeBilling),
          _Action('Trust Accounting', 'Matter trust ledgers and reconciliation.', Icons.account_balance_wallet, AppRoutes.legalTrust),
        ], embedded: true),
      ],
    );
  }

  Widget _intake() {
    final rows = (_data as List?)?.cast<Map<String, dynamic>>() ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: ListTile(
          leading: const Icon(Icons.policy),
          title: const Text('Conflict checks are part of intake'),
          subtitle: const Text('Screen adverse parties and related entities before converting an instruction into a matter.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.legalConflicts),
        )),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No client intake records yet.')))
        else
          ...rows.map((r) => Card(child: ListTile(
            title: Text('${r['prospective_client_name'] ?? r['title'] ?? r['id']}'),
            subtitle: Text('${r['status'] ?? 'INTAKE'}'),
          ))),
      ],
    );
  }

  Widget _records(String emptyMessage) {
    final rows = (_data as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (rows.isEmpty) return Center(child: Text(emptyMessage));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = rows[index];
        final title = row['title'] ?? row['search_terms'] ?? row['period_end'] ?? row['id'];
        final status = row['status'] ?? row['result'] ?? '';
        return Card(child: ListTile(
          title: Text('$title'),
          subtitle: status.toString().isEmpty ? null : Text('$status'),
        ));
      },
    );
  }

  Widget _hub(List<_Action> actions, {bool embedded = false}) {
    final content = Wrap(
      spacing: 16,
      runSpacing: 16,
      children: actions.map((action) => SizedBox(
        width: 360,
        child: Card(child: ListTile(
          contentPadding: const EdgeInsets.all(18),
          leading: Icon(action.icon),
          title: Text(action.title),
          subtitle: Text(action.description),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(action.route),
        )),
      )).toList(),
    );
    if (embedded) return content;
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: content);
  }
}

class _Action {
  final String title;
  final String description;
  final IconData icon;
  final String route;
  const _Action(this.title, this.description, this.icon, this.route);
}
