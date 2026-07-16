import 'dart:convert';
import '../api_client.dart';
import '../models/user.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  Future<List<User>> getUsers({Map<String, dynamic>? query}) async {
    try {
      final response = await ApiClient().get('/v2/user', queryParameters: query);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => User.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<User> getUser(String userId) async {
    try {
      final response = await ApiClient().get('/v2/user/$userId');
      if (response.statusCode == 200) {
        return User.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        throw Exception('Failed to load user: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserRoles(String userId) async {
    try {
      final response = await ApiClient().get('/v2/user/$userId/role');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<void> updateUserRoles(String userId, List<String> roles) async {
    try {
      final response = await ApiClient().post(
        '/v2/user/$userId/role',
        body: roles,
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to update user roles: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<User> createUser({
    required String username,
    required String password,
    required String email,
    required String cellphone,
    required String userType,
    required String partnerId,
    String accountType = 'STANDARD',
    bool testUser = false,
    bool protectedUser = false,
    bool systemManaged = false,
    String accessScope = 'STANDARD',
    String environmentScope = '',
    bool externalTransactionsBlocked = false,
    DateTime? expiresAt,
    String protectedReason = '',
    bool mfaRequired = false,
  }) async {
    try {
      final response = await ApiClient().post(
        '/v2/user',
        body: {
          'username': username,
          'password': password,
          'email': email,
          'cellphone': cellphone,
          'userType': userType,
          'partnerId': partnerId,
          'accountType': accountType,
          'testUser': testUser,
          'protectedUser': protectedUser,
          'systemManaged': systemManaged,
          'accessScope': accessScope,
          'environmentScope': environmentScope,
          'externalTransactionsBlocked': externalTransactionsBlocked,
          'expiresAt': expiresAt?.toIso8601String(),
          'protectedReason': protectedReason,
          'mfaRequired': mfaRequired,
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create user: ${response.body}');
      }
      return User.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> body) async {
    final response = await ApiClient().put('/v2/user/$userId', body: body);
    if (response.statusCode != 200) {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to update user');
    }
  }

  Future<void> deleteUser(String userId) async {
    final response = await ApiClient().delete('/v2/user/$userId');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to delete user');
    }
  }

  Future<void> lockUser(String userId, {required String reason}) async {
    try {
      final response = await ApiClient().put(
        '/v2/user/$userId/lock',
        queryParameters: {'reason': reason},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to lock user: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> unlockUser(String userId) async {
    try {
      final response = await ApiClient().put('/v2/user/$userId/unlock');
      if (response.statusCode != 200) {
        throw Exception('Failed to unlock user: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetUser(String userId) async {
    try {
      final response = await ApiClient().put('/v2/user/$userId/reset');
      if (response.statusCode != 200) {
        throw Exception('Failed to reset user: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<User> getUserByUsername(String username) async {
    try {
      final response = await ApiClient().get('/v2/user/username/$username');
      if (response.statusCode == 200) {
        return User.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        throw Exception('Failed to load user by username: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<User> getUserByPartnerId(String partnerId) async {
    try {
      final response = await ApiClient().get('/v2/user/partner/$partnerId');
      if (response.statusCode == 200) {
        return User.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        throw Exception('Failed to load user by partner ID: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<User> getUserByEmail(String email) async {
    try {
      final response = await ApiClient().get('/v2/user/email/$email');
      if (response.statusCode == 200) {
        return User.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        throw Exception('Failed to load user by email: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<User> getUserByCellphone(String cellphone) async {
    try {
      final response = await ApiClient().get('/v2/user/cellphone/$cellphone');
      if (response.statusCode == 200) {
        return User.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        throw Exception('Failed to load user by cellphone: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
