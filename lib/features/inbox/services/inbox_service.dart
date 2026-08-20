import 'dart:convert';

import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../models/inbox.dart';

class InboxService {
  final ApiClient _apiClient = ApiClient();

  Future<UserInbox> getInbox({int limit = 80}) async {
    final response = await _apiClient.get(
      '/v2/inbox',
      queryParameters: {'limit': limit},
    );
    if (response.statusCode != 200) {
      throw AppException(_message(response.body, 'Unable to load your inbox.'));
    }
    return UserInbox.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
  }


  Future<List<InboxNotification>> getUnreadNotifications({int limit = 20}) async {
    final response = await _apiClient.get(
      '/v2/inbox/notifications',
      queryParameters: {'limit': limit, 'unreadOnly': true},
    );
    if (response.statusCode != 200) {
      throw AppException(_message(response.body, 'Unable to load inbox notifications.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .map((item) => InboxNotification.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<InboxCounts> getCounts() async {
    final response = await _apiClient.get('/v2/inbox/counts');
    if (response.statusCode != 200) {
      throw AppException(_message(response.body, 'Unable to load inbox counts.'));
    }
    return InboxCounts.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
  }

  Future<void> markRead(String notificationId) async {
    final response = await _apiClient.put('/v2/inbox/$notificationId/read');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_message(response.body, 'Unable to mark notification as read.'));
    }
  }

  Future<void> markAllRead() async {
    final response = await _apiClient.put('/v2/inbox/read-all');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_message(response.body, 'Unable to mark notifications as read.'));
    }
  }

  String _message(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final value = decoded['message'] ?? decoded['error'];
        if (value != null && value.toString().trim().isNotEmpty) return value.toString();
      }
    } catch (_) {}
    return fallback;
  }
}
