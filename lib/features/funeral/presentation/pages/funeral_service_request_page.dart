import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/funeral_service_request_dto.dart';
import '../../services/funeral_service_request_service.dart';
import '../widgets/funeral_status_chip.dart';

class FuneralServiceRequestPage extends StatefulWidget {
  const FuneralServiceRequestPage({super.key});

  @override
  State<FuneralServiceRequestPage> createState() => _FuneralServiceRequestPageState();
}

class _FuneralServiceRequestPageState extends State<FuneralServiceRequestPage> {
  final FuneralServiceRequestService _service = FuneralServiceRequestService();
  final TextEditingController _searchController = TextEditingController();

  List<FuneralServiceRequestDto> _requests = [];
  bool _isLoading = true;
  String? _statusFilter;
  Timer? _searchDebounce;

  static const List<String> _statuses = [
    'ARRANGEMENT_CREATED',
    'CLAIMS_INITIATED',
    'CLAIMS_RESOLVED',
    'INVOICES_GENERATED',
    'COMPLETED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final requests = await _service.getServiceRequests(
        query: _searchController.text,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading funeral service requests: $e')),
      );
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadRequests);
  }

  Future<void> _openCreateWizard() async {
    await context.push(AppRoutes.funeralNewServiceRequest);
    if (mounted) _loadRequests();
  }

  void _openInvoicePreview(FuneralServiceRequestDto request) {
    final id = request.id;
    if (id == null || id.isEmpty) return;
    context.push('/funeral/service-request/$id/invoice-preview');
  }

  void _openClaims(FuneralServiceRequestDto request) {
    final id = request.id;
    if (id == null || id.isEmpty) return;
    context.push('/funeral/service-request/$id/claims');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Funeral Service Requests'),
        actions: [
          IconButton(
            onPressed: _loadRequests,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateWizard,
        icon: const Icon(Icons.add),
        label: const Text('Create Arrangement'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search deceased, ID, location or status',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadRequests();
                              },
                            ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.tune),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      ..._statuses.map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(_label(status)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _statusFilter = value);
                      _loadRequests();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? _EmptyServiceRequests(onCreate: _openCreateWizard)
                    : RefreshIndicator(
                        onRefresh: _loadRequests,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          itemCount: _requests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _FuneralServiceRequestCard(
                            request: _requests[index],
                            onClaims: () => _openClaims(_requests[index]),
                            onInvoicePreview: () => _openInvoicePreview(_requests[index]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  static String _label(String value) => value.replaceAll('_', ' ');
}

class _EmptyServiceRequests extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyServiceRequests({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volunteer_activism_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('No funeral service requests found'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create Funeral Arrangement'),
          ),
        ],
      ),
    );
  }
}

class _FuneralServiceRequestCard extends StatelessWidget {
  final FuneralServiceRequestDto request;
  final VoidCallback onClaims;
  final VoidCallback onInvoicePreview;

  const _FuneralServiceRequestCard({
    required this.request,
    required this.onClaims,
    required this.onInvoicePreview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = request.status ?? 'ARRANGEMENT_CREATED';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.deceasedName.isEmpty ? 'Unknown deceased' : request.deceasedName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (request.deceasedIdentityNumber.isNotEmpty) 'ID ${request.deceasedIdentityNumber}',
                          if (request.funeralLocation.isNotEmpty) request.funeralLocation,
                          'Funeral ${Formatters.formatFriendlyDate(request.funeralDate)}',
                        ].join(' • '),
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FuneralStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _InfoItem(label: 'Amount', value: Formatters.formatCentsAsRand(request.totalAmountCents)),
                _InfoItem(label: 'Created', value: Formatters.formatFriendlyDate(request.createdAt)),
                if (request.id != null && request.id!.isNotEmpty)
                  _InfoItem(label: 'Request ID', value: request.id!),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onClaims,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Claims'),
                ),
                FilledButton.icon(
                  onPressed: onInvoicePreview,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Invoice Preview'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
