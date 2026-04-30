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
        return data.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load users');
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
