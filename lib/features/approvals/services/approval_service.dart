import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/api_client.dart';
import '../models/approval.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class ApprovalService {
  final ApiClient _apiClient = ApiClient();

  Future<Approval> submitApproval(ApprovalSubmission submission) async {
    final response = await _apiClient.post(
      '/v2/approval/submit',
      body: submission.toJson(),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw AppException.fromHttp(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallback: 'The approval request could not be submitted. Review the information and try again.',
      );
    }
  }

  Future<List<Approval>> getApprovals({
    String? status,
    String? approvalType,
    String? requesterId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status;
    if (approvalType != null) queryParams['approvalType'] = approvalType;
    if (requesterId != null) queryParams['requesterId'] = requesterId;

    try {
      final response = await _apiClient.get(
        '/v2/approval',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data;
        
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('content')) {
          data = decoded['content'] ?? [];
        } else {
          data = [];
        }
        
        return data.map((item) => Approval.fromJson(Map<String, dynamic>.from(item))).toList();
      } else {
        throw AppException('Failed to load approvals: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ApprovalService Error: $e');
      rethrow;
    }
  }

  Future<Approval> getApprovalById(String id) async {
    final response = await _apiClient.get('/v2/approval/$id');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw AppException('Failed to load approval: ${response.statusCode}');
    }
  }

  Future<List<ApprovalAction>> getAuditTrail(String approvalRequestId) async {
    final response = await _apiClient.get('/v2/approval/$approvalRequestId/audit');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => ApprovalAction.fromJson(item)).toList();
    } else {
      throw AppException('Failed to load audit trail: ${response.statusCode}');
    }
  }

  Future<Approval> approve(
    String id, {
    String? comments,
    String? actionBy,
    int? arrearsMonths,
  }) async {
    final response = await _apiClient.post(
      '/v2/approval/$id/approve',
      body: {
        'comments': comments,
        'actionBy': actionBy,
        if (arrearsMonths != null) 'arrearsMonths': arrearsMonths,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw AppException.fromHttp(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallback: 'The approval could not be completed. Please try again.',
      );
    }
  }

  Future<Approval> reject(String id, {String? comments, String? actionBy}) async {
    final response = await _apiClient.post(
      '/v2/approval/$id/reject',
      body: {
        'comments': comments,
        'actionBy': actionBy,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw AppException.fromHttp(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallback: 'The approval request could not be rejected. Please try again.',
      );
    }
  }

  Future<Approval> cancel(String id, {String? comments, String? actionBy}) async {
    final response = await _apiClient.post(
      '/v2/approval/$id/cancel',
      body: {
        'comments': comments,
        'actionBy': actionBy,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw AppException.fromHttp(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallback: 'The approval request could not be cancelled. Please try again.',
      );
    }
  }
}
