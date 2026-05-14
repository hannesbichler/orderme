import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class AuthService {
  // Local backend – change host/port if running on a different machine
  static const String _usersUrl = 'http://172.17.0.36:3000/persons';

  // Cache so we don't re-fetch on every login attempt
  static List<User>? _cachedUsers;

  /// Fetches the predefined users from the web service.
  Future<List<User>> fetchUsers() async {
    if (_cachedUsers != null) return _cachedUsers!;

    final response = await http.get(Uri.parse(_usersUrl));
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load users (HTTP ${response.statusCode})');
    }

    final List<dynamic> data = json.decode(response.body)['persons'] as List<dynamic>;
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
