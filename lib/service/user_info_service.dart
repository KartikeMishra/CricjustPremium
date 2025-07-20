import 'dart:convert';
import 'package:http/http.dart' as http;

class UserInfoService {
  static const String _baseUrl =
      'https://cricjust.in/wp-json/custom-api-for-cricket';

  /// Update user info using POST request
  static Future<Map<String, dynamic>> updateUserInfo({
    required String apiToken,
    required Map<String, String> updatedFields,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/update-user-info?api_logged_in_token=$apiToken',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: updatedFields,
    );

    final body = json.decode(response.body);
    if (response.statusCode != 200 || body['status'] != 1) {
      throw Exception(
        'Failed to update user info: ${body['message'] ?? 'Unknown error'}',
      );
    }

    return body; // includes status, message, updated data
  }
}
