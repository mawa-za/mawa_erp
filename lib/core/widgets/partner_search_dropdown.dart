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
  List<Partner> _partners = [];
  bool _isLoading = true;
  String? _error;
  Partner? _selectedPartner;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    try {
      final partners = await PartnerService().getPartnersByRole(widget.role);
      if (mounted) {
        setState(() {
          _partners = partners;
          _isLoading = false;
          
          if (widget.initialPartnerId != null && _partners.isNotEmpty) {
            try {
              _selectedPartner = _partners.firstWhere(
                (p) => p.id == widget.initialPartnerId,
              );
            } catch (_) {
              _selectedPartner = null;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: LinearProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListTile(
        title: Text('Error loading partners: $_error', style: const TextStyle(color: Colors.red, fontSize: 12)),
        trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPartners),
      );
    }

    if (_partners.isEmpty) {
      return const ListTile(
        title: Text('No employees found to link', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
      );
    }

    return DropdownButtonFormField<Partner>(
      value: _selectedPartner,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.person_search_outlined),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true,
      items: _partners.map((partner) {
        return DropdownMenuItem<Partner>(
          value: partner,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(partner.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(partner.number, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        );
      }).toList(),
      onChanged: (Partner? newValue) {
        setState(() => _selectedPartner = newValue);
        widget.onPartnerSelected(newValue);
      },
      validator: widget.validator,
      selectedItemBuilder: (context) {
        return _partners.map((partner) {
          return Text(
            partner.fullName, 
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          );
        }).toList();
      },
    );
  }
}
