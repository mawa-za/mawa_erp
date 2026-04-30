import 'dart:convert';
import '../api_client.dart';
import '../models/user.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  Future<List<User>> getUsers() async {
    try {
      final response = await ApiClient().get('/v2/user');
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

  Future<List<String>> getUserRoles(String userId) async {
    try {
      final response = await ApiClient().get('/v2/user/$userId/role');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => e.toString()).toList();
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

  Future<void> createUser({
    required String username,
    required String password,
    required String email,
    required String cellphone,
    required String userType,
    required String partnerId,
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
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create user: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> lockUser(String userId) async {
    try {
      final response = await ApiClient().put('/v2/user/$userId/lock');
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
}
