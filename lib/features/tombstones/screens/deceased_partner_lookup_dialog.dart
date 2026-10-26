import 'package:flutter/material.dart';

import '../../../core/errors/app_error.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';

/// Optional link to an existing MAWA deceased partner.
///
/// This deliberately does NOT create a partner: a family-only tombstone request
/// can be captured directly from the family's details without a deceased
/// partner ID, identity number, funeral, or mortuary admission.
class DeceasedPartnerLookupDialog extends StatefulWidget {
  final String initialQuery;

  const DeceasedPartnerLookupDialog({super.key, this.initialQuery = ''});

  @override
  State<DeceasedPartnerLookupDialog> createState() =>
      _DeceasedPartnerLookupDialogState();
}

class _DeceasedPartnerLookupDialogState
    extends State<DeceasedPartnerLookupDialog> {
  final _searchController = TextEditingController();
  List<Partner> _results = const [];
  bool _searching = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Enter at least two characters to search.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _hasSearched = false;
      _results = const [];
    });
    try {
      final partners = await PartnerService().getPartners(query: query);
      final matches = partners.where((partner) =>
          partner.id.trim().isNotEmpty &&
          partner.type.toUpperCase() == 'INDIVIDUAL').toList();
      if (!mounted) return;
      setState(() {
        _results = matches;
        _hasSearched = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.person_search),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Link existing deceased partner',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: 12),
              const Text(
                'Optional: search MAWA by the deceased name, identity number, or partner number. '
                'If no record exists, close this dialog and use the family-provided details. '
                'A deceased partner record is not required.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) { if (!_searching) _search(); },
                decoration: const InputDecoration(
                  labelText: 'Deceased name, ID number or partner number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: const Text('Search existing partner'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
              ],
              if (_hasSearched && _results.isEmpty) ...[
                const SizedBox(height: 16),
                const Text('No existing individual partner found. '
                    'You can continue without linking one.'),
              ],
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Select the correct deceased person:'),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final partner = _results[index];
                      final subtitle = [
                        if (partner.number.isNotEmpty) 'Partner #${partner.number}',
                        if (partner.identityNumber.isNotEmpty)
                          partner.identityNumber,
                      ].join(' • ');
                      return ListTile(
                        title: Text(partner.fullName),
                        subtitle: subtitle.isEmpty ? null : Text(subtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, partner),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
