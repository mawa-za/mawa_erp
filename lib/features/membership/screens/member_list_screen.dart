import 'package:flutter/material.dart';
import '../models/membership.dart';
import '../services/membership_service.dart';
import 'add_member_screen.dart';
import 'membership_detail_screen.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  bool _isLoading = true;
  List<Membership> _memberships = [];
  List<Membership> _filteredMemberships = [];
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMemberships();
  }

  Future<void> _fetchMemberships() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final memberships = await MembershipService().getMemberships();
      if (mounted) {
        setState(() {
          _memberships = memberships;
          _filteredMemberships = memberships;
          _isLoading = false;
          _applySearch(_searchController.text);
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

  void _applySearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMemberships = _memberships;
      } else {
        final q = query.toLowerCase();
        _filteredMemberships = _memberships.where((m) =>
          m.transactionNumber.toLowerCase().contains(q) ||
          m.mainPartner.toLowerCase().contains(q) ||
          (m.product?.toLowerCase().contains(q) ?? false) ||
          (m.identityNumber?.toLowerCase().contains(q) ?? false)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Memberships', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMemberships,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorWidget(colorScheme)
                    : _filteredMemberships.isEmpty
                        ? _buildEmptyWidget()
                        : _buildMembershipList(colorScheme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddMemberScreen()),
          );
          if (result == true) {
            _fetchMemberships();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _applySearch,
        decoration: InputDecoration(
          hintText: 'Search by number, partner or product...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _applySearch('');
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
      ),
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('Failed to load memberships', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _fetchMemberships,
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_membership_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No memberships found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMembershipList(ColorScheme colorScheme) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredMemberships.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final membership = _filteredMemberships[index];
        return _buildMembershipCard(membership, colorScheme);
      },
    );
  }

  Widget _buildMembershipCard(Membership membership, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MembershipDetailScreen(membershipId: membership.transactionId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${membership.transactionNumber}',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  _buildStatusChip(membership.transactionStatus),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                membership.mainPartner.isEmpty ? 'Unknown Partner' : membership.mainPartner,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    membership.product ?? 'No Product',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SUBTYPE', style: TextStyle(fontSize: 10, color: Colors.grey[500], letterSpacing: 0.5)),
                      Text(membership.transactionSubtype, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('CREATED', style: TextStyle(fontSize: 10, color: Colors.grey[500], letterSpacing: 0.5)),
                      Text(membership.creationDate.split(',').first, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'WAITING-PERIOD':
      case 'UPGRADE-WAITING-PERIOD':
        color = Colors.orange;
        break;
      case 'INACTIVE':
        color = Colors.red;
        break;
      case 'NEW':
      case 'AWAITING-APPROVAL':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.replaceAll('-', ' '),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
