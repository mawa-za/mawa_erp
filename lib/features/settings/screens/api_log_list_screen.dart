import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/api_endpoint_log.dart';
import '../services/log_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class ApiLogListScreen extends StatefulWidget {
  const ApiLogListScreen({super.key});

  @override
  State<ApiLogListScreen> createState() => _ApiLogListScreenState();
}

class _ApiLogListScreenState extends State<ApiLogListScreen> {
  final LogService _logService = LogService();
  final ScrollController _scrollController = ScrollController();
  
  List<ApiEndpointLog> _logs = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInitialLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && _error == null) {
        _fetchMoreLogs();
      }
    }
  }

  Future<void> _fetchInitialLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _logs = [];
    });

    try {
      final response = await _logService.getApiEndpointLogs(
        page: _currentPage,
        size: _pageSize,
        sort: ['createdAt,desc'],
      );
      if (mounted) {
        setState(() {
          _logs = response.content;
          _hasMore = !response.last;
          _isLoading = false;
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

  Future<void> _fetchMoreLogs() async {
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final response = await _logService.getApiEndpointLogs(
        page: nextPage,
        size: _pageSize,
        sort: ['createdAt,desc'],
      );
      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _logs.addAll(response.content);
          _hasMore = !response.last;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error loading more logs: $e'))),
        );
      }
    }
  }

  Color _getStatusColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return Colors.green;
    if (statusCode >= 400 && statusCode < 500) return Colors.orange;
    if (statusCode >= 500) return Colors.red;
    return Colors.blue;
  }

  List<ApiEndpointLog> get _visibleLogs {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _logs;
    return _logs.where((log) => [
      log.method,
      log.endpoint,
      log.statusCode.toString(),
      log.direction,
      log.integrationName ?? '',
      log.username ?? '',
      log.requestId ?? '',
      log.requestIp ?? '',
      log.errorMessage ?? '',
    ].join(' ').toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logs = _visibleLogs;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('API Activity Logs', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchInitialLogs,
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search API activity',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchInitialLogs, child: const Text('Retry')),
                    ],
                  ),
                )
              : logs.isEmpty
                  ? const Center(child: Text('No logs found.'))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length + (_searchQuery.trim().isEmpty && _hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == logs.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final log = logs[index];
                        return _buildLogCard(log);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(ApiEndpointLog log) {
    final statusColor = _getStatusColor(log.statusCode);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    
    // Parse createdAt if it's a string, or format if it's already a date-like string
    String formattedDate = log.createdAt;
    try {
      final dt = DateTime.parse(log.createdAt);
      formattedDate = dateFormat.format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              log.statusCode.toString(),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        title: Text(
          '${log.method} ${log.endpoint}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              formattedDate,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            _buildBadge(log.direction),
            if ((log.integrationName ?? '').isNotEmpty)
              _buildBadge(log.integrationName!),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          _buildInfoRow('User', log.username ?? 'Anonymous'),
          _buildInfoRow('IP Address', log.requestIp ?? 'Unknown'),
          _buildInfoRow('Duration', '${log.durationMs} ms'),
          _buildInfoRow('Request ID', log.requestId ?? 'N/A'),
          if (log.queryString != null && log.queryString!.isNotEmpty)
            _buildInfoRow('Query', log.queryString!),
          if (log.errorMessage != null && log.errorMessage!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Error Message:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          if (log.userAgent != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Client:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(log.userAgent!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          if ((log.requestBody ?? '').isNotEmpty)
            _buildBodySection('Request Body', log.requestBody!),
          if ((log.responseBody ?? '').isNotEmpty)
            _buildBodySection('Response Body', log.responseBody!),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBodySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title:',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 320),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                body,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
