import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../models/partner.dart';
import 'partner_create_screen.dart';
import 'partner_detail_screen.dart';

class PartnerListScreen extends StatefulWidget {
  final String? role;
  final String? title;
  final bool allowCreate;

  const PartnerListScreen({
    super.key,
    this.role,
    this.title,
    this.allowCreate = true,
  });

  @override
  State<PartnerListScreen> createState() => _PartnerListScreenState();
}

class _PartnerListScreenState extends State<PartnerListScreen> {
  bool _isLoading = true;
  List<Partner> _partners = [];
  String? _error;
  String _selectedType = 'ALL';
  String _selectedStatus = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  final List<String> _types = ['ALL', 'INDIVIDUAL', 'ORGANISATION', 'GROUP'];
  final List<String> _statuses = ['ALL', 'ACTIVE', 'PENDING', 'INACTIVE', 'ARCHIVED', 'DECEASED'];

  @override
  void initState() {
    super.initState();
    _fetchPartners();
  }

  Future<void> _fetchPartners() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String path = '/v2/partner';
      
      final Map<String, String> params = {
        'query': _searchController.text,
        'role': widget.role ?? '',
      };
      
      final uri = Uri.parse(path).replace(queryParameters: params);
      final response = await ApiClient().get(uri.toString());
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final allPartners = data.map((json) => Partner.fromJson(json)).toList();
        
        allPartners.sort((a, b) => b.number.compareTo(a.number));
        setState(() {
          _partners = allPartners.where((partner) {
            final typeMatches = _selectedType == 'ALL' || partner.type.toUpperCase() == _selectedType;
            final statusMatches = _selectedStatus == 'ALL' || partner.status.toUpperCase() == _selectedStatus;
            return typeMatches && statusMatches;
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load partners: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entityName = widget.role == 'MEMBER' ? 'Member' : 'Partner';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.title ?? 'Business Partners'),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _fetchPartners,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(entityName),
          _buildTypeFilter(),
          _buildStatusFilter(),
          Expanded(child: _buildBody(colorScheme, entityName)),
        ],
      ),
      floatingActionButton: widget.allowCreate ? FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PartnerCreateScreen(
                isMemberContext: widget.role == 'MEMBER',
              ),
            ),
          );
          _fetchPartners();
        },
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  Widget _buildSearchBar(String entityName) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search ${entityName.toLowerCase()}s...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _fetchPartners();
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          fillColor: Colors.grey[100],
          filled: true,
        ),
        onSubmitted: (_) => _fetchPartners(),
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      height: 50,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _types.length,
        itemBuilder: (context, index) {
          final type = _types[index];
          final isSelected = _selectedType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                type,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87
                )
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedType = type);
                  _fetchPartners();
                }
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.grey[100],
              side: BorderSide.none,
              showCheckmark: false,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }


  Widget _buildStatusFilter() {
    return Container(
      height: 50,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = _statuses[index];
          final selected = status == _selectedStatus;
          return ChoiceChip(
            label: Text(status, style: const TextStyle(fontSize: 11)),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedStatus = status);
              _fetchPartners();
            },
            showCheckmark: false,
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
          );
        },
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, String entityName) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPartners,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_partners.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No ${entityName.toLowerCase()}s found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _partners.length,
      itemBuilder: (context, index) {
        final partner = _partners[index];
        return _buildPartnerCard(partner, colorScheme);
      },
    );
  }

  Widget _buildPartnerCard(Partner partner, ColorScheme colorScheme) {
    IconData icon;
    switch (partner.type) {
      case 'ORGANISATION':
        icon = Icons.business;
        break;
      case 'GROUP':
        icon = Icons.groups;
        break;
      default:
        icon = Icons.person;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PartnerDetailScreen(
                partnerId: partner.id,
                isMemberContext: widget.role == 'MEMBER',
              ),
            ),
          );
          _fetchPartners();
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No: ${partner.number} • ${partner.type}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (partner.identityNumber.isNotEmpty)
                      Text(
                        'ID: ${partner.identityNumber}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusChip(partner.status),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    final s = status.toUpperCase();
    if (s == 'ACTIVE') color = Colors.green;
    else if (s == 'INACTIVE') color = Colors.red;
    else if (s == 'DECEASED') color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        s,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
