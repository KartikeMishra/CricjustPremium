import 'dart:convert';
import 'package:http/http.dart' as http;

class PermissionService {
  static const String _base = 'https://cricjust.in/wp-json/custom-api-for-cricket';

  static Future<List<Map<String, dynamic>>> getTypeList({
    required String token,
    required String type, // 'matches' | 'teams'
  }) async {
    final uri = Uri.parse('$_base/get-type-list-for-permissions?api_logged_in_token=$token&type=$type');
    final res = await http.get(uri);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    if (map['status'] != 1) return [];
    final List data = map['data'] ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<bool> addPermission({
    required String token, // SENDER token
    required String type,  // 'matches' | 'teams'
    required int typeId,
    required String assignUserPhone,
  }) async {
    final uri = Uri.parse('$_base/add-permission?api_logged_in_token=$token');
    final res = await http.post(uri, body: {
      'type': type,
      'type_id': '$typeId',
      'assign_user_phone': assignUserPhone,
    });

    Map<String, dynamic> map;
    try {
      map = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }
    return (map['status'] == 1 || map['status'] == '1');
  }
}
