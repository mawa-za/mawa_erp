import 'dart:convert';

import '../api_client.dart';
import '../../features/home/models/tenant_experience.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class TenantExperienceService {
  Future<TenantExperience?> getExperience() async {
    final response = await ApiClient().get('/tenant-experience');
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AppException(
        response.body.isNotEmpty
            ? response.body
            : 'Failed to load tenant industry experience',
      );
    }
    if (response.body.trim().isEmpty) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final experience = TenantExperience.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    return experience.sections.isEmpty ? null : experience;
  }
}
