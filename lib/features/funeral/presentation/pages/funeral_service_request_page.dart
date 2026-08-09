import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/files/download_bytes.dart';
import '../../data/funeral_api.dart';
import '../../data/models/funeral_service_request_dto.dart';
import '../widgets/funeral_status_chip.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class FuneralServiceRequestPage extends StatefulWidget {
  const FuneralServiceRequestPage({super.key});

  @override
  State<FuneralServiceRequestPage> createState() =>
      _FuneralServiceRequestPageState();
}

class _FuneralServiceRequestPageState extends State<FuneralServiceRequestPage> {
  final FuneralApi _api = FuneralApi();
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  List<FuneralServiceRequestDto> _requests = const [];
  bool _loading = true;
  String? _error;
  String _status = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _api.getServiceRequests(
        query: _search.text,
        status: _status == 'ALL' ? null : _status,
      );
      requests.sort((a, b) => b.funeralDate.compareTo(a.funeralDate));
      if (mounted) setState(() => _requests = requests);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newRequest() async {
    await context.push(AppRoutes.funeralNewServiceRequest);
    await _load();
  }

  Future<void> _downloadConfirmationLetter(FuneralServiceRequestDto request) async {
    final id = request.id;
    if (id == null || id.isEmpty) return;
    try {
      final bytes = await _api.downloadConfirmationLetter(id);
      final reference = request.serviceRequestNo?.trim().isNotEmpty == true
          ? request.serviceRequestNo!.trim()
          : id;
      await downloadBytes(
        bytes: Uint8List.fromList(bytes),
        fileName: 'funeral-confirmation-$reference.pdf',
        mimeType: 'application/pdf',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage('Unable to generate confirmation letter: $error'))),
      );
    }
  }

  Future<void> _downloadServiceRequestForm(FuneralServiceRequestDto request) async {
    final id = request.id;
    if (id == null || id.isEmpty) return;
    try {
      final bytes = await _api.downloadServiceRequestForm(id);
      final reference = request.serviceRequestNo?.trim().isNotEmpty == true
          ? request.serviceRequestNo!.trim()
          : id;
      await downloadBytes(
        bytes: Uint8List.fromList(bytes),
        fileName: 'funeral-service-request-$reference.pdf',
        mimeType: 'application/pdf',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage('Unable to generate service request form: $error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_ZA', symbol: 'R ');
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Funeral Service Requests'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRequest,
        icon: const Icon(Icons.add),
        label: const Text('New Arrangement'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 450), _load);
              },
              decoration: const InputDecoration(
                labelText: 'Search request number, deceased or identity number',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              children: ['ALL', 'COVER_IDENTIFIED', 'ARRANGEMENT_CREATED', 'CLAIMS_INITIATED', 'CLAIMS_RESOLVED', 'INVOICED']
                  .map((status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status.replaceAll('_', ' ')),
                          selected: _status == status,
                          onSelected: (_) {
                            setState(() => _status = status);
                            _load();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(child: _body(currency)),
        ],
      ),
    );
  }

  Widget _body(NumberFormat currency) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volunteer_activism_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('No funeral service requests found.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _newRequest,
              icon: const Icon(Icons.add),
              label: const Text('New Arrangement'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final request = _requests[index];
          final id = request.id ?? '';
          final completed = request.status?.toUpperCase() == 'INVOICED';
          return Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: InkWell(
              onTap: id.isEmpty || completed ? null : () async {
                await context.push('/funeral/service-request/$id/resume');
                await _load();
              },
              child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.serviceRequestNo?.isNotEmpty == true
                              ? request.serviceRequestNo!
                              : 'Funeral Service Request',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      FuneralStatusChip(status: request.status ?? 'DRAFT'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(request.deceasedName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Text('ID: ${request.deceasedIdentityNumber.isEmpty ? '-' : request.deceasedIdentityNumber}'),
                      Text('Funeral: ${Formatters.formatDate(request.funeralDate)}'),
                      Text('Area: ${request.funeralLocation.isEmpty ? '-' : request.funeralLocation}'),
                      Text('Total: ${currency.format(request.totalAmountCents / 100)}'),
                    ],
                  ),
                  if (request.deceasedDeliveryDirections.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Directions: ${request.deceasedDeliveryDirections}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!completed)
                        FilledButton.tonalIcon(
                          onPressed: id.isEmpty ? null : () async {
                            await context.push('/funeral/service-request/$id/resume');
                            await _load();
                          },
                          icon: const Icon(Icons.play_arrow_outlined),
                          label: Text(request.wizardStep > 0 ? 'Resume Arrangement' : 'Continue Arrangement'),
                        ),
                      OutlinedButton.icon(
                        onPressed: id.isEmpty ? null : () => context.push('/funeral/service-request/$id/claims'),
                        icon: const Icon(Icons.request_quote_outlined),
                        label: const Text('Claims'),
                      ),
                      OutlinedButton.icon(
                        onPressed: id.isEmpty ? null : () => context.push('/funeral/service-request/$id/invoice-preview'),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Invoice Preview'),
                      ),
                      OutlinedButton.icon(
                        onPressed: id.isEmpty ? null : () => _downloadConfirmationLetter(request),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Confirmation Letter'),
                      ),
                      OutlinedButton.icon(
                        onPressed: id.isEmpty ? null : () => _downloadServiceRequestForm(request),
                        icon: const Icon(Icons.assignment_outlined),
                        label: const Text('Service Request Form'),
                      ),
                    ],
                  ),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }
}
