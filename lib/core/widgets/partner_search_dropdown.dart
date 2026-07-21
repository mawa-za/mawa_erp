import 'package:flutter/material.dart';
import '../../features/partners/models/partner.dart';
import '../../features/partners/partner_service.dart';

class PartnerSearchDropdown extends StatefulWidget {
  final String role;
  final String label;
  final String? initialPartnerId;
  final ValueChanged<Partner?> onPartnerSelected;
  final String? Function(Partner?)? validator;

  const PartnerSearchDropdown({
    super.key,
    required this.role,
    required this.label,
    this.initialPartnerId,
    required this.onPartnerSelected,
    this.validator,
  });

  @override
  State<PartnerSearchDropdown> createState() => _PartnerSearchDropdownState();
}

class _PartnerSearchDropdownState extends State<PartnerSearchDropdown> {
  static const Duration _searchDebounce = Duration(milliseconds: 450);
  static const int _minimumQueryLength = 2;

  Partner? _selectedPartner;
  final SearchController _searchController = SearchController();
  final PartnerService _partnerService = PartnerService();
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialPartnerId != null) {
      _loadInitialPartner();
    }
  }

  Future<void> _loadInitialPartner() async {
    try {
      // Logic for initial partner loading could go here
    } catch (e) {
      debugPrint('Error loading initial partner: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<Partner>(
      validator: widget.validator,
      initialValue: _selectedPartner,
      builder: (FormFieldState<Partner> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchAnchor(
              searchController: _searchController,
              builder: (context, controller) {
                return SearchBar(
                  controller: controller,
                  onTap: () => controller.openView(),
                  onChanged: (_) => controller.openView(),
                  hintText: _selectedPartner?.fullName ?? widget.label,
                  leading: const Icon(Icons.person_search_outlined),
                  trailing: [
                    if (_selectedPartner != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedPartner = null;
                            _searchController.clear();
                          });
                          widget.onPartnerSelected(null);
                          state.didChange(null);
                        },
                      ),
                  ],
                  elevation: const WidgetStatePropertyAll(0),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: state.hasError ? Colors.red : Colors.grey.shade400),
                    ),
                  ),
                  backgroundColor: const WidgetStatePropertyAll(Colors.white),
                  constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
                );
              },
              suggestionsBuilder: (context, controller) async {
                final query = controller.text.trim();
                final generation = ++_searchGeneration;

                if (query.length < _minimumQueryLength) {
                  return const [
                    ListTile(
                      leading: Icon(Icons.search),
                      title: Text('Enter at least 2 characters to search'),
                    ),
                  ];
                }

                await Future<void>.delayed(_searchDebounce);
                if (!mounted ||
                    generation != _searchGeneration ||
                    controller.text.trim() != query) {
                  return const <Widget>[];
                }

                try {
                  final partners = await _partnerService.getPartnersByRole(
                    widget.role,
                    query: query,
                  );

                  if (!mounted ||
                      generation != _searchGeneration ||
                      controller.text.trim() != query) {
                    return const <Widget>[];
                  }

                  if (partners.isEmpty) {
                    return [
                      ListTile(
                        title: Text('No ${widget.label.toLowerCase()} found'),
                      ),
                    ];
                  }

                  return partners.map((partner) {
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person, size: 20),
                      ),
                      title: Text(
                        partner.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'No: ${partner.number} • ${partner.identityNumber}',
                      ),
                      onTap: () {
                        setState(() {
                          _selectedPartner = partner;
                          _searchController.text = partner.fullName;
                          controller.closeView(partner.fullName);
                        });
                        widget.onPartnerSelected(partner);
                        state.didChange(partner);
                      },
                    );
                  }).toList();
                } catch (e) {
                  if (!mounted ||
                      generation != _searchGeneration ||
                      controller.text.trim() != query) {
                    return const <Widget>[];
                  }
                  return [
                    ListTile(
                      title: Text(
                        'Error loading partners: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ];
                }
              },
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: Text(
                  state.errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
