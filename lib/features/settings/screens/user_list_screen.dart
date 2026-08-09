import 'package:flutter/material.dart';
import '../../../core/models/user.dart';
import '../../../core/services/user_service.dart';
import 'user_detail_screen.dart';
import 'user_create_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  bool _isLoading = true;
  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  String? _error;
  String _selectedStatus = 'ALL';
  final List<String> _statuses = ['ALL', 'ACTIVE', 'PENDING', 'LOCKED', 'INACTIVE'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await UserService().getUsers();
      if (mounted) {
        setState(() {
          users.sort((a, b) {
            final byDate = (b.validFrom ?? '').compareTo(a.validFrom ?? '');
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
          _applySearch(_searchController.text);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  void _applySearch(String query) {
    setState(() {
      final lowercaseQuery = query.toLowerCase();
      _filteredUsers = _allUsers.where((user) {
        final statusMatches = _selectedStatus == 'ALL' || user.status.toUpperCase() == _selectedStatus;
        final searchMatches = query.isEmpty ||
            user.username.toLowerCase().contains(lowercaseQuery) ||
            (user.email?.toLowerCase().contains(lowercaseQuery) ?? false);
        return statusMatches && searchMatches;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Users', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatusFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorWidget(colorScheme)
                    : _filteredUsers.isEmpty
                        ? _buildEmptyWidget()
                        : _buildUserList(colorScheme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const UserCreateScreen()),
          ).then((value) {
            if (value == true) _fetchUsers();
          });
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
          hintText: 'Search users...',
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

  Widget _buildStatusFilter() {
    return Container(
      height: 52,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = _statuses[index];
          return ChoiceChip(
            label: Text(status, style: const TextStyle(fontSize: 11)),
            selected: _selectedStatus == status,
            showCheckmark: false,
            onSelected: (_) {
              setState(() => _selectedStatus = status);
              _applySearch(_searchController.text);
            },
          );
        },
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
            Text('Failed to load users', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _fetchUsers,
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
          Icon(Icons.person_search_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No users found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildUserList(ColorScheme colorScheme) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredUsers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user, colorScheme);
      },
    );
  }

  Widget _buildUserCard(User user, ColorScheme colorScheme) {
    final String initials = user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U';

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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withOpacity(0.1),
          child: Text(
            initials,
            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.username,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (user.protectedUser) ...[
              _buildMiniBadge('PROTECTED', Colors.green),
              const SizedBox(width: 6),
            ],
            if (user.testUser) ...[
              _buildMiniBadge('TEST', Colors.orange),
              const SizedBox(width: 6),
            ],
            _buildStatusBadge(user.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    user.email ?? 'No email',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.badge_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${user.type} • ${user.accountType}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserDetailScreen(userId: user.id),
            ),
          ).then((_) => _fetchUsers());
        },
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool isActive = status.toUpperCase() == 'ACTIVE';
    final Color color = isActive ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
