import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_client.dart';
import '../models/access_profile.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AccessProfileService {
  static const _keys = <String>[
    'accountType', 'testUser', 'protectedUser', 'systemManaged', 'accessScope',
    'environmentScope', 'externalTransactionsBlocked', 'accessExpiresAt',
    'mfaRequired', 'platformSession', 'platformUserId', 'handoffId',
    'accessReason', 'ticketReference', 'accessTenantId', 'allWorkcentres',
  ];

  Future<AccessProfile> getProfile() async {
    final response = await ApiClient().get('/v2/access/profile');
    if (response.statusCode != 200) {
      throw AppException(response.body.isNotEmpty
          ? response.body
          : 'Failed to load access profile');
    }
    final profile = AccessProfile.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
    await persistProfile(profile);
    return profile;
  }

  Future<void> persistAuthentication(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accountType', (data['accountType'] ?? 'STANDARD').toString());
    await prefs.setBool('testUser', data['testUser'] == true);
    await prefs.setBool('protectedUser', data['protectedUser'] == true);
    await prefs.setString('accessScope', (data['accessScope'] ?? 'STANDARD').toString());
    await prefs.setBool('platformSession', data['platformSession'] == true);
    await prefs.setString('platformUserId', (data['platformUserId'] ?? '').toString());
    await prefs.setString('accessTenantId', (data['tenantId'] ?? '').toString());
    await prefs.setBool('externalTransactionsBlocked', data['externalTransactionsBlocked'] == true);
    await prefs.setString('accessExpiresAt', (data['expiresAt'] ?? '').toString());
    await prefs.setString('handoffId', (data['handoffId'] ?? '').toString());
    await prefs.setString('accessReason', (data['accessReason'] ?? '').toString());
    await prefs.setString('ticketReference', (data['ticketReference'] ?? '').toString());
  }

  Future<void> persistProfile(AccessProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accountType', p.accountType);
    await prefs.setBool('testUser', p.testUser);
    await prefs.setBool('protectedUser', p.protectedUser);
    await prefs.setBool('systemManaged', p.systemManaged);
    await prefs.setString('accessScope', p.accessScope);
    await prefs.setString('environmentScope', p.environmentScope);
    await prefs.setBool('externalTransactionsBlocked', p.externalTransactionsBlocked);
    await prefs.setString('accessExpiresAt', p.expiresAt?.toIso8601String() ?? '');
    await prefs.setBool('mfaRequired', p.mfaRequired);
    await prefs.setBool('platformSession', p.platformSession);
    await prefs.setString('platformUserId', p.platformUserId);
    await prefs.setString('handoffId', p.handoffId);
    await prefs.setString('accessReason', p.accessReason);
    await prefs.setString('ticketReference', p.ticketReference);
    await prefs.setString('accessTenantId', p.tenantId);
    await prefs.setBool('allWorkcentres', p.allWorkcentres);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _keys) {
      await prefs.remove(key);
    }
  }
}
