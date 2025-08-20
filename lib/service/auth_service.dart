import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/login_result.dart';

class AuthService {
  static const String _base =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  /// Logs in and returns LoginResult (contains api token + userId).
  /// Adjust field names if your backend expects different ones.
  static Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$_base/login');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        // Commonly: user_login + user_pass; change if your API differs
        'user_login': username,
        'user_pass': password,
      },
    );

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    if ((body['status'] ?? 0) != 1) {
      throw Exception(body['message']?.toString() ?? 'Login failed');
    }

    return LoginResult.fromJson(body);
  }
}
