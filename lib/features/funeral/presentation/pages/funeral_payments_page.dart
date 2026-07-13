import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/formatters.dart';
import '../../data/funeral_api.dart';
import '../../data/models/funeral_payment_summary_dto.dart';
import 'funeral_invoice_payment_page.dart';

class FuneralPaymentsPage extends StatefulWidget {
  const FuneralPaymentsPage({super.key});

  @override
  State<FuneralPaymentsPage> createState() => _FuneralPaymentsPageState();
}

class _FuneralPaymentsPageState extends State<FuneralPaymentsPage> {
  final FuneralApi _api = FuneralApi();
  final TextEditingController _searchController = TextEditingController();
  List<FuneralPaymentSummaryDto> _payments = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payments = await _api.getFuneralPayments();
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<FuneralPaymentSummaryDto> get _filtered {
    final term = _searchController.text.trim().toLowerCase();
    return _payments.where((payment) {
      final matchesStatus = _filter == 'ALL' ||
          (_filter == 'OUTSTANDING' && payment.balanceCents > 0) ||
          (_filter == 'PAID' && payment.balanceCents <= 0);
      if (!matchesStatus) return false;
      if (term.isEmpty) return true;
      return payment.invoiceNo.toLowerCase().contains(term) ||
          payment.serviceRequestNo.toLowerCase().contains(term) ||
          payment.deceasedName.toLowerCase().contains(term) ||
          payment.entityType.toLowerCase().contains(term);
    }).toList();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/feature-groups/funeral-management');
    }
  }

  Future<void> _capturePayment(FuneralPaymentSummaryDto payment) async {
    if (payment.invoiceId.isEmpty) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FuneralInvoicePaymentPage(invoiceId: payment.invoiceId),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: const Text('Funeral Payments'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search funeral invoices',
                hintText: 'Invoice, arrangement or deceased name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final filter in const ['ALL', 'OUTSTANDING', 'PAID'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(error: _error!, onRetry: _load)
                    : items.isEmpty
                        ? const _EmptyState()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final payment = items[index];
                                return _FuneralPaymentCard(
                                  payment: payment,
                                  onCapture: payment.balanceCents > 0
                                      ? () => _capturePayment(payment)
                                      : null,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _FuneralPaymentCard extends StatelessWidget {
  const _FuneralPaymentCard({
    required this.payment,
    required this.onCapture,
  });

  final FuneralPaymentSummaryDto payment;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isPaid = payment.balanceCents <= 0;
    final date = payment.invoiceDate == null
        ? ''
        : DateFormat('dd MMM yyyy').format(payment.invoiceDate!);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.invoiceNo.isEmpty
                            ? 'Funeral invoice'
                            : payment.invoiceNo,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [payment.serviceRequestNo, payment.deceasedName, date]
                            .where((value) => value.trim().isNotEmpty)
                            .join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(isPaid ? 'PAID' : payment.status),
                  avatar: Icon(
                    isPaid ? Icons.check_circle : Icons.pending_outlined,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _AmountLabel(
                  label: 'Invoice',
                  value: Formatters.formatCentsAsRand(
                    payment.invoiceTotalCents,
                  ),
                ),
                _AmountLabel(
                  label: 'Paid',
                  value: Formatters.formatCentsAsRand(payment.paidCents),
                ),
                _AmountLabel(
                  label: 'Balance',
                  value: Formatters.formatCentsAsRand(payment.balanceCents),
                  emphasized: !isPaid,
                ),
              ],
            ),
            if (onCapture != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Capture Payment'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountLabel extends StatelessWidget {
  const _AmountLabel({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                color: emphasized
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No funeral invoices have been generated yet.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
