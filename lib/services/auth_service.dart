import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import 'app_settings_service.dart';

class AuthService {
  // Cache so we don't re-fetch on every login attempt
  static List<User>? _cachedUsers;

  static Uri get _usersUri =>
      Uri.parse('${AppSettingsService.baseUrl}/persons');

  static void invalidateCache() {
    _cachedUsers = null;
  }

  /// Fetches the predefined users from the web service.
  Future<List<User>> fetchUsers() async {
    if (_cachedUsers != null) return _cachedUsers!;

    final response = await http.get(_usersUri);
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load users (HTTP ${response.statusCode})');
    }

    final List<dynamic> data = json.decode(response.body)['_embedded']['personList'] as List<dynamic>;
    _cachedUsers = data
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cachedUsers!;
  }

  /// Returns the matching [User] if username + email match a fetched user,
  /// otherwise returns null.
  Future<User?> login(String username, String password) async {
    final users = await fetchUsers();
    try {
      // "password" is the user's email address (from the web-service data)
      return users.firstWhere(
        (u) =>
            u.name.toLowerCase() == username.toLowerCase() // &&
           // u.email.toLowerCase() == password.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
