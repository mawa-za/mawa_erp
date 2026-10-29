import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/files/download_bytes.dart';
import '../../../../core/services/field_service.dart';
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
  Map<String, String> _salesAreaLabels = const {};
  bool _loading = true;
  String? _error;
  String _status = 'ARRANGEMENT_CREATED';

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
      final requestsFuture = _api.getServiceRequests(
        query: _search.text,
        status: _status == 'ALL' ? null : _status,
      );
      final salesAreasFuture = _salesAreaLabels.isEmpty
          ? FieldService().getOptionsByField('SALES-AREA')
          : null;
      final requests = await requestsFuture;
      if (salesAreasFuture != null) {
        final salesAreas = await salesAreasFuture;
        _salesAreaLabels = {
          for (final option in salesAreas) option.code.toUpperCase(): option.description,
          for (final option in salesAreas) option.description.toUpperCase(): option.description,
        };
      }
      requests.sort((a, b) {
        final byMembership = (b.membershipNo ?? '').compareTo(a.membershipNo ?? '');
        return byMembership != 0
            ? byMembership
            : (b.serviceRequestNo ?? '').compareTo(a.serviceRequestNo ?? '');
      });
      if (mounted) setState(() => _requests = requests);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _salesAreaLabel(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '-';
    return _salesAreaLabels[normalized.toUpperCase()] ?? normalized;
  }

  Future<void> _newRequest() async {
    await context.push(AppRoutes.funeralNewServiceRequest);
    await _load();
  }

  Future<void> _changePackage(FuneralServiceRequestDto request) async {
    final serviceId = request.id;
    if (serviceId == null || serviceId.isEmpty) return;
    try {
      final packages = await _api.getFuneralPackages();
      final options = packages.where((p) => p.id != request.packageId).toList();
      if (!mounted) return;
      String? selected;
      String reason = '';
      bool acknowledged = false;
      bool submitting = false;
      String? previewError;
      Map<String, dynamic>? preview;
      final submitted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, redraw) => AlertDialog(
            title: Text('Change Package - ${request.serviceRequestNo ?? ''}'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current arrangement: ${request.deceasedName}'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Replacement funeral package'),
                      value: selected,
                      isExpanded: true,
                      items: options.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} - R ${(p.basePriceCents / 100).toStringAsFixed(2)}'),
                      )).toList(),
                      onChanged: submitting ? null : (next) async {
                        redraw(() { selected = next; preview = null; previewError = null; });
                        if (next == null) return;
                        try {
                          final result = await _api.previewPackageAmendment(serviceId, next);
                          if (dialogContext.mounted && selected == next) redraw(() => preview = result);
                        } catch (error) {
                          if (dialogContext.mounted) redraw(() => previewError = friendlyErrorMessage(error));
                        }
                      },
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 12),
                      Text('Current total: R ${((preview!['currentTotalCents'] as num) / 100).toStringAsFixed(2)}'),
                      Text('Revised total: R ${((preview!['revisedTotalCents'] as num) / 100).toStringAsFixed(2)}'),
                      Text('Difference: R ${((preview!['differenceCents'] as num) / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (preview!['historicPackageSnapshotAvailable'] == false)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Historical package items were not snapshotted. Verify the original agreement before submitting.'),
                        ),
                      if (preview!['requiresFundingReconciliation'] == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Funding reconciliation will be required before this amendment can be applied.'),
                        ),
                    ],
                    if (previewError != null) Text(previewError!,
                      style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
                    const SizedBox(height: 12),
                    TextFormField(
                      minLines: 2,
                      maxLines: 4,
                      enabled: !submitting,
                      decoration: const InputDecoration(labelText: 'Reason for package change'),
                      onChanged: (v) => redraw(() => reason = v),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: acknowledged,
                      title: const Text('Customer or authorised family representative has acknowledged the revised arrangement'),
                      onChanged: submitting ? null : (v) => redraw(() => acknowledged = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const Text('The original invoices and claims will be preserved. Financial adjustments need approval.'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: submitting ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('CANCEL')),
              FilledButton(
                onPressed: submitting || selected == null || preview == null || !acknowledged || reason.trim().isEmpty
                    ? null : () async {
                  redraw(() => submitting = true);
                  try {
                    await _api.submitPackageAmendment(serviceId, selected!, reason);
                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                  } catch (error) {
                    if (dialogContext.mounted) {
                      redraw(() { submitting = false; previewError = friendlyErrorMessage(error); });
                    }
                  }
                },
                child: Text(submitting ? 'SUBMITTING...' : 'SUBMIT FOR APPROVAL'),
              ),
            ],
          ),
        ),
      );
      if (submitted == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Package change submitted for approval.')));
        await _load();
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))));
    }
  }

  Future<void> _restoreClaimDocuments(FuneralServiceRequestDto request) async {
    final serviceId = request.id;
    if (serviceId == null) return;
    try {
      final restored = await _api.restoreFuneralClaimContext(serviceId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Refreshed claim details for $restored claims. Print new forms to see the corrected details.'),
      ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyErrorMessage(error)),
      ));
    }
  }

  Future<void> _downloadAmendmentPdf(Map<String, dynamic> amendment) async {
    try {
      final id = amendment['id'].toString();
      final bytes = await _api.downloadPackageAmendment(id);
      await downloadBytes(
        bytes: Uint8List.fromList(bytes),
        fileName: 'funeral-amendment-${amendment['amendmentNo'] ?? id}.pdf',
        mimeType: 'application/pdf',
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))));
    }
  }

  Future<void> _showPackageAmendments(FuneralServiceRequestDto request) async {
    final serviceId = request.id;
    if (serviceId == null) return;
    try {
      final amendments = await _api.getPackageAmendments(serviceId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Package Amendment History - ${request.serviceRequestNo ?? ''}'),
          content: SizedBox(
            width: 560,
            child: amendments.isEmpty
                ? const Text('No amendments recorded.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: amendments.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final item = amendments[i];
                      final amount = ((item['newTotalCents'] as num) - (item['oldTotalCents'] as num)) / 100;
                      return ListTile(
                        title: Text(item['amendmentNo']?.toString() ?? 'Amendment'),
                        subtitle: Text('${item['status']} | R ${amount.toStringAsFixed(2)}\n'
                            '${item['reason'] ?? ''}\n${item['reconciliationNote'] ?? ''}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Download amendment PDF',
                              onPressed: () => _downloadAmendmentPdf(item),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                            ),
                            if (item['status'] == 'RECONCILIATION_REQUIRED')
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await _api.applyApprovedPackageAmendment(item['id'].toString());
                                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                                    await _load();
                                  } catch (error) {
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                                        SnackBar(content: Text(friendlyErrorMessage(error))));
                                    }
                                  }
                                },
                                child: const Text('RECHECK'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CLOSE'))],
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))));
    }
  }

  Future<void> _cancelRequest(FuneralServiceRequestDto request) async {
    final id = request.id;
    if (id == null || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Funeral Service Request'),
        content: Text('Cancel ${request.serviceRequestNo ?? 'this funeral service request'}? This arrangement cannot be resumed afterwards.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('KEEP REQUEST')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CANCEL REQUEST')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.cancelServiceRequest(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Funeral service request cancelled.'), backgroundColor: Colors.green),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
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
              children: ['ALL', 'COVER_IDENTIFIED', 'ARRANGEMENT_CREATED', 'CLAIMS_INITIATED', 'CLAIMS_RESOLVED', 'INVOICED', 'CANCELLED']
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
          final cancelled = request.status?.toUpperCase() == 'CANCELLED';
          return Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: InkWell(
              onTap: id.isEmpty || completed || cancelled ? null : () async {
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
                      Text('Area: ${_salesAreaLabel(request.funeralLocation)}'),
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
                  if (request.deceasedDeliveryDateTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Deceased delivery: ${Formatters.formatDate(request.deceasedDeliveryDateTime!)} '
                      '${TimeOfDay.fromDateTime(request.deceasedDeliveryDateTime!).format(context)}',
                    ),
                  ],
                  if (!cancelled) ...[
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
                        label: const Text('Manage Funding & Claims'),
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
                        if (completed) ...[
                          OutlinedButton.icon(
                            onPressed: id.isEmpty ? null : () => _restoreClaimDocuments(request),
                            icon: const Icon(Icons.sync),
                            label: const Text('Refresh Claim Documents'),
                          ),
                          OutlinedButton.icon(
                            onPressed: id.isEmpty ? null : () => _changePackage(request),
                            icon: const Icon(Icons.change_circle_outlined),
                            label: const Text('Change Package'),
                          ),
                          OutlinedButton.icon(
                            onPressed: id.isEmpty ? null : () => _showPackageAmendments(request),
                            icon: const Icon(Icons.history),
                            label: const Text('Amendment History'),
                          ),
                        ],
                        if (!completed)
                          OutlinedButton.icon(
                          onPressed: id.isEmpty ? null : () => _cancelRequest(request),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel Request'),
                          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                          ),
                      ],
                    ),
                  ],
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
